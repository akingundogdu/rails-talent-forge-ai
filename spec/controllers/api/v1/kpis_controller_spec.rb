require 'rails_helper'

RSpec.describe Api::V1::KpisController, type: :controller do
  let(:user) { create(:user) }
  let(:employee) { create(:employee, user: user) }
  let(:kpi) { create(:kpi, employee: employee) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_employee).and_return(employee)
  end

  describe 'GET #index' do
    let!(:own_kpi) { create(:kpi, employee: employee) }
    let!(:other_kpi) { create(:kpi) }

    it 'returns own KPIs only' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => own_kpi.id))
      expect(json_response['data']).not_to include(hash_including('id' => other_kpi.id))
    end

    it 'filters by measurement unit' do
      currency_kpi = create(:kpi, :currency_kpi, employee: employee)

      get :index, params: { measurement_unit: 'currency' }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => currency_kpi.id))
    end

    it 'filters by measurement period' do
      monthly_kpi = create(:kpi, :monthly, employee: employee)

      get :index, params: { measurement_period: 'monthly' }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(hash_including('id' => monthly_kpi.id))
    end

    it 'includes achievement calculations' do
      get :index
      expect(response).to have_http_status(:ok)
      
      kpi_data = json_response['data'].first
      expect(kpi_data['achievement_percentage']).to be_present
      expect(kpi_data['achievement_status']).to be_present
      expect(kpi_data['formatted_actual']).to be_present
    end
  end

  describe 'GET #show' do
    before do
      # Create department peers with same KPI name for benchmarking
      3.times do
        peer = create(:employee, position: create(:position, department: employee.position.department))
        create(:kpi, employee: peer, name: kpi.name, actual_value: rand(80..120))
      end
    end

    it 'returns KPI details with analytics' do
      get :show, params: { id: kpi.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(
        'id' => kpi.id,
        'name' => kpi.name,
        'achievement_percentage' => kpi.achievement_percentage.to_s
      )
    end

    it 'includes benchmarking data' do
      get :show, params: { id: kpi.id }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['department_average']).to be_present
    end
  end

  describe 'POST #create' do
    let(:valid_params) {
      {
        kpi: {
          name: 'Monthly Sales Revenue',
          description: 'Total sales revenue generated monthly',
          target_value: 50000,
          actual_value: 45000,
          measurement_unit: 'currency',
          measurement_period: 'monthly',
          period_start: Date.current.beginning_of_month,
          period_end: Date.current.end_of_month
        }
      }
    }

    it 'creates a new KPI' do
      expect {
        post :create, params: valid_params
      }.to change(Kpi, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['data']['name']).to eq('Monthly Sales Revenue')
    end

    it 'validates required fields' do
      invalid_params = {
        kpi: {
          name: '',
          target_value: -100
        }
      }

      post :create, params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to be_an(Array)
      expect(json_response['errors'].join(' ')).to include('Name')
      expect(json_response['errors'].join(' ')).to include('Target value')
    end
  end

  describe 'PATCH #update' do
    it 'updates KPI actual value' do
      patch :update, params: {
        id: kpi.id,
        kpi: { actual_value: 12000 }
      }

      expect(response).to have_http_status(:ok)
      kpi.reload
      expect(kpi.actual_value).to eq(12000)
    end

    it 'recalculates achievement status after update' do
      patch :update, params: {
        id: kpi.id,
        kpi: { actual_value: kpi.target_value * 1.2 }
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['achievement_status']).to eq('exceeds_target')
    end
  end

  describe 'GET #dashboard' do
    before do
      create_list(:kpi, 3, :excellent_performance, employee: employee)
      create_list(:kpi, 2, :poor_performance, employee: employee)
    end

    it 'returns comprehensive KPI dashboard' do
      get :dashboard
      expect(response).to have_http_status(:ok)
      
      dashboard = json_response['data']
      expect(dashboard['total_kpis']).to eq(5) # 3 excellent + 2 poor (existing kpi not counted in accessible_employee_ids)
      expect(dashboard['excellent_count']).to be >= 0
      expect(dashboard['needs_attention_count']).to be >= 0
      expect(dashboard['average_achievement']).to be_present
    end

    it 'includes trending KPIs' do
      get :dashboard
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['trending_up']).to be_present
      expect(json_response['data']['trending_down']).to be_present
    end
  end

  describe 'GET #benchmarks' do
    let(:department) { employee.position.department }

    before do
      # Create department peers with KPIs
      3.times do
        peer = create(:employee, position: create(:position, department: department))
        create(:kpi, employee: peer, name: 'Sales Performance', actual_value: rand(80..120))
      end
    end

    it 'returns benchmarking data against department' do
      get :benchmarks, params: { kpi_name: 'Sales Performance' }
      expect(response).to have_http_status(:ok)
      
      benchmarks = json_response['data']
      expect(benchmarks['department_average']).to be_present
      expect(benchmarks['your_percentile']).to be_present
      expect(benchmarks['comparison_data']).to be_present
    end

    it 'includes position-level benchmarks' do
      get :benchmarks, params: { kpi_name: 'Sales Performance', include_position: true }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['position_average']).to be_present
    end
  end

  describe 'GET #trends' do
    before do
      # Create historical KPI data
      6.times do |i|
        create(:kpi, 
          employee: employee,
          name: 'Revenue Growth',
          actual_value: 1000 + (i * 100),
          created_at: i.months.ago
        )
      end
    end

    it 'returns trend analysis for KPIs' do
      get :trends, params: { period: 6, kpi_name: 'Revenue Growth' }
      expect(response).to have_http_status(:ok)
      
      trends = json_response['data']
      expect(trends['period_months']).to eq(6)
      expect(trends['kpi_name']).to eq('Revenue Growth')
      expect(trends['trend_data']).to be_an(Array)
    end

    it 'handles different time periods' do
      get :trends, params: { period: 3, kpi_name: 'Revenue Growth' }
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['trend_data'].length).to eq(3)
    end
  end

  describe 'GET #analytics' do
    before do
      create_list(:kpi, 5, employee: employee, measurement_unit: :currency)
      create_list(:kpi, 3, employee: employee, measurement_unit: :percentage)
    end

    it 'returns comprehensive KPI analytics' do
      get :analytics
      expect(response).to have_http_status(:ok)
      
      analytics = json_response['data']
      expect(analytics['total_kpis']).to be_present
      expect(analytics['average_achievement']).to be_present
      expect(analytics['by_measurement_unit']).to be_present
    end

    it 'includes performance insights' do
      get :analytics
      expect(response).to have_http_status(:ok)
      expect(json_response['data']['performance_insights']).to be_a(Hash)
      expect(json_response['data']['performance_insights']['underperforming']).to be_present
    end
  end

  describe 'POST #bulk_update' do
    let!(:kpis) { create_list(:kpi, 3, employee: employee) }

    it 'updates multiple KPIs at once' do
      updates = kpis.map.with_index { |k, i| { id: k.id, actual_value: (i + 1) * 1000 } }

      post :bulk_update, params: { kpis: updates }
      expect(response).to have_http_status(:ok)

      kpis.each_with_index do |kpi, index|
        kpi.reload
        expect(kpi.actual_value).to eq((index + 1) * 1000)
      end
    end

    it 'validates bulk update data' do
      invalid_updates = [{ id: 999999, actual_value: 100 }]

      post :bulk_update, params: { kpis: invalid_updates }
      expect(response).to have_http_status(:not_found)
      expect(json_response['errors']).to be_present
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end 