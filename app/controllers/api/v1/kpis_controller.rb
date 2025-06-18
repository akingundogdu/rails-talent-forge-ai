class Api::V1::KpisController < ApplicationController
  before_action :authenticate_user!
  before_action :set_kpi, only: [:show, :update, :destroy, :update_progress, :complete, :archive]
  before_action :authorize_kpi_access, only: [:show, :update, :destroy, :update_progress, :complete, :archive]

  # GET /api/v1/kpis
  def index
    @kpis = Kpi.includes(:employee, :position)
    
    # Filter by current user's accessible employees (self and subordinates)
    employee_ids = accessible_employee_ids
    @kpis = @kpis.where(employee_id: employee_ids) if employee_ids.any?
    
    # Filter by employee
    @kpis = @kpis.for_employee(params[:employee_id]) if params[:employee_id].present?
    
    # Filter by position
    @kpis = @kpis.for_position(params[:position_id]) if params[:position_id].present?
    
    # Filter by measurement unit
    @kpis = @kpis.by_measurement_unit(params[:measurement_unit]) if params[:measurement_unit].present?
    
    # Filter by measurement period
    @kpis = @kpis.where(measurement_period: params[:measurement_period]) if params[:measurement_period].present?
    
    # Filter by status
    @kpis = @kpis.where(status: params[:status]) if params[:status].present?
    
    # Filter by period
    if params[:period_start].present? && params[:period_end].present?
      @kpis = @kpis.in_period(Date.parse(params[:period_start]), Date.parse(params[:period_end]))
    end
    
    # Current period filter
    @kpis = @kpis.current_period if params[:current_period] == 'true'
    
    # Performance filters
    @kpis = @kpis.underperforming if params[:underperforming] == 'true'
    @kpis = @kpis.overperforming if params[:overperforming] == 'true'
    
    # Search functionality
    @kpis = @kpis.search(params[:search]) if params[:search].present?
    
    # Pagination
    @kpis = @kpis.page(params[:page]).per(params[:per_page] || 20)
    
    render json: {
      data: kpis_json(@kpis),
      meta: pagination_meta(@kpis)
    }
  end

  # GET /api/v1/kpis/:id
  def show
    render json: {
      data: kpi_detail_json(@kpi)
    }
  end

  # POST /api/v1/kpis
  def create
    @kpi = Kpi.new(kpi_params)
    @kpi.employee = current_employee
    
    if @kpi.save
      render json: {
        data: kpi_detail_json(@kpi),
        message: 'KPI created successfully'
      }, status: :created
    else
      render json: {
        errors: @kpi.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/kpis/:id
  def update
    if @kpi.update(kpi_params)
      render json: {
        data: kpi_detail_json(@kpi),
        message: 'KPI updated successfully'
      }
    else
      render json: {
        errors: @kpi.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/kpis/:id
  def destroy
    if @kpi.destroy
      render json: {
        message: 'KPI deleted successfully'
      }
    else
      render json: {
        errors: @kpi.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/kpis/:id/update_progress
  def update_progress
    actual_value = params[:actual_value]
    notes = params[:notes]
    
    if @kpi.update_progress!(actual_value, notes)
      render json: {
        data: kpi_detail_json(@kpi),
        message: 'KPI progress updated successfully'
      }
    else
      render json: {
        errors: @kpi.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/kpis/:id/complete
  def complete
    completion_notes = params[:completion_notes]
    
    if @kpi.complete!(completion_notes)
      render json: {
        data: kpi_detail_json(@kpi),
        message: 'KPI marked as completed successfully'
      }
    else
      render json: {
        errors: ['KPI cannot be completed in current state']
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/kpis/:id/archive
  def archive
    reason = params[:reason]
    
    if @kpi.archive!(reason)
      render json: {
        data: kpi_detail_json(@kpi),
        message: 'KPI archived successfully'
      }
    else
      render json: {
        errors: ['KPI cannot be archived in current state']
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/kpis/dashboard
  def dashboard
    employee_ids = accessible_employee_ids
    kpis = Kpi.where(employee_id: employee_ids)
    
    dashboard_data = {
      total_kpis: kpis.count,
      active_kpis: kpis.status_active.count,
      completed_kpis: kpis.status_completed.count,
      excellent_count: kpis.select { |k| k.achievement_status == 'exceeds_target' }.count,
      needs_attention_count: kpis.select { |k| k.achievement_status == 'poor' }.count,
      average_achievement: kpis.average(:actual_value)&.round(2) || 0,
      trending_up: kpis.select { |k| k.trend_direction == 'up' }.count,
      trending_down: kpis.select { |k| k.trend_direction == 'down' }.count
    }
    
    render json: {
      data: dashboard_data
    }
  end

  # GET /api/v1/kpis/benchmarks
  def benchmarks
    kpi_name = params[:kpi_name] || 'Sales Performance'
    include_position = params[:include_position] == 'true'
    employee = current_employee
    department = employee.position.department
    
    # Get department peers' KPIs
    department_kpis = Kpi.joins(employee: { position: :department })
                         .where(positions: { department_id: department.id })
                         .where(name: kpi_name)
    
    department_average = department_kpis.average(:actual_value)&.round(2) || 0
    user_kpi = department_kpis.find_by(employee: employee)
    user_value = user_kpi&.actual_value || 0
    
    # Calculate percentile
    better_count = department_kpis.where('actual_value < ?', user_value).count
    total_count = department_kpis.count
    percentile = total_count > 0 ? (better_count.to_f / total_count * 100).round(0) : 0
    
    # Position-level benchmarks if requested
    position_average = nil
    if include_position
      position_kpis = department_kpis.joins(:employee)
                                   .where(employees: { position_id: employee.position_id })
      position_average = position_kpis.average(:actual_value)&.round(2) || 0
    end
    
    render json: {
      data: {
        kpi_name: kpi_name,
        department_average: department_average,
        position_average: position_average,
        your_value: user_value,
        your_percentile: percentile,
        comparison_data: {
          department_count: total_count,
          above_average: department_kpis.where('actual_value > ?', department_average).count
        }
      }
    }
  end

  # GET /api/v1/kpis/trending
  def trending
    employee_id = params[:employee_id]
    kpi_name = params[:kpi_name]
    months = params[:months]&.to_i || 6
    
    if employee_id.blank? || kpi_name.blank?
      return render json: {
        errors: ['Employee ID and KPI name are required']
      }, status: :bad_request
    end
    
    trending_data = Kpi.trending_analysis(employee_id, kpi_name, months)
    
    render json: {
      data: {
        employee_id: employee_id,
        kpi_name: kpi_name,
        months: months,
        trending_data: trending_data
      }
    }
  end

  # POST /api/v1/kpis/bulk_create_for_position
  def bulk_create_for_position
    position_id = params[:position_id]
    kpi_templates = params[:kpi_templates] || []
    
    if position_id.blank? || kpi_templates.empty?
      return render json: {
        errors: ['Position ID and KPI templates are required']
      }, status: :bad_request
    end
    
    begin
      Kpi.bulk_create_for_position(position_id, kpi_templates)
      render json: {
        message: 'KPIs created successfully for all employees in position'
      }
    rescue StandardError => e
      render json: {
        errors: [e.message]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/kpis/trends
  def trends
    period = params[:period]&.to_i || 6
    kpi_name = params[:kpi_name] || 'Revenue Growth'
    employee_ids = accessible_employee_ids
    
    # Get historical KPI data
    kpis = Kpi.where(employee_id: employee_ids, name: kpi_name)
              .where('created_at >= ?', period.months.ago)
              .order(:created_at)
    
    # Simple trend data - group by month manually
    trend_data = []
    period.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_kpis = kpis.where(created_at: month_start..month_end)
      avg_value = month_kpis.average(:actual_value)&.round(2) || 0
      
      trend_data << {
        month: month_start.strftime('%Y-%m'),
        average_value: avg_value,
        count: month_kpis.count
      }
    end
    
    render json: {
      data: {
        period_months: period,
        kpi_name: kpi_name,
        trend_data: trend_data.reverse
      }
    }
  end

  # GET /api/v1/kpis/analytics
  def analytics
    employee_ids = accessible_employee_ids
    kpis = Kpi.where(employee_id: employee_ids)
    
    # Calculate average achievement manually
    total_achievement = 0
    kpis.each { |kpi| total_achievement += kpi.achievement_percentage }
    avg_achievement = kpis.count > 0 ? (total_achievement / kpis.count).round(2) : 0
    
    render json: {
      data: {
        total_kpis: kpis.count,
        active_kpis: kpis.active_kpis.count,
        completed_kpis: kpis.completed_kpis.count,
        average_achievement: avg_achievement,
        by_measurement_unit: kpis.group(:measurement_unit).count,
        by_status: kpis.group(:status).count,
        performance_insights: {
          underperforming: kpis.underperforming.count,
          overperforming: kpis.overperforming.count
        }
      }
    }
  end

  # POST /api/v1/kpis/bulk_update
  def bulk_update
    kpis_data = params[:kpis] || []
    
    begin
      Kpi.transaction do
        kpis_data.each do |kpi_update|
          kpi = Kpi.find(kpi_update[:id])
          
          # Check authorization for each KPI
          employee = current_employee
          unless employee == kpi.employee || 
                 employee == kpi.employee.manager ||
                 current_user.admin? || 
                 current_user.super_admin?
            raise StandardError, "Unauthorized access to KPI #{kpi.id}"
          end
          
          kpi.update!(actual_value: kpi_update[:actual_value])
        end
      end
      
      render json: {
        message: 'KPIs updated successfully'
      }
    rescue ActiveRecord::RecordNotFound => e
      render json: {
        errors: ['One or more KPIs not found']
      }, status: :not_found
    rescue StandardError => e
      render json: {
        errors: [e.message]
      }, status: :unprocessable_entity
    end
  end

  private

  def set_kpi
    @kpi = Kpi.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['KPI not found'] }, status: :not_found
  end

  def authorize_kpi_access
    employee = current_employee
    
    # Allow access if user is the KPI owner, manager, or admin
    unless employee == @kpi.employee || 
           employee == @kpi.employee.manager ||
           current_user.admin? || 
           current_user.super_admin?
      render json: { errors: ['Unauthorized access'] }, status: :forbidden
    end
  end

  def kpi_params
    params.require(:kpi).permit(
      :employee_id, :position_id, :name, :description,
      :target_value, :actual_value, :measurement_unit,
      :period_start, :period_end, :status
    )
  end

  def kpis_json(kpis)
    kpis.map do |kpi|
      {
        id: kpi.id,
        name: kpi.name,
        description: kpi.description,
        employee: {
          id: kpi.employee.id,
          name: kpi.employee.full_name,
          position: kpi.employee.position.title
        },
        position: kpi.position ? {
          id: kpi.position.id,
          name: kpi.position.title,
          department: kpi.position.department.name
        } : nil,
        target_value: kpi.target_value,
        actual_value: kpi.actual_value,
        formatted_target: kpi.formatted_target,
        formatted_actual: kpi.formatted_actual,
        achievement_percentage: kpi.achievement_percentage,
        achievement_status: kpi.achievement_status,
        measurement_unit: kpi.measurement_unit,
        period_start: kpi.period_start,
        period_end: kpi.period_end,
        status: kpi.status,
        is_overdue: kpi.is_overdue?,
        is_on_track: kpi.is_on_track?,
        created_at: kpi.created_at,
        updated_at: kpi.updated_at
      }
    end
  end

  def kpi_detail_json(kpi)
    # Calculate department average for benchmarking
    department_kpis = Kpi.joins(employee: { position: :department })
                         .where(positions: { department_id: kpi.employee.position.department.id })
                         .where(name: kpi.name)
    department_average = department_kpis.average(:actual_value)&.round(2) || 0
    
    {
      id: kpi.id,
      name: kpi.name,
      description: kpi.description,
      employee: {
        id: kpi.employee.id,
        name: kpi.employee.full_name,
        email: kpi.employee.email,
        position: kpi.employee.position.title,
        department: kpi.employee.department.name
      },
      position: kpi.position ? {
        id: kpi.position.id,
        name: kpi.position.title,
        department: kpi.position.department.name,
        level: kpi.position.level
      } : nil,
      target_value: kpi.target_value,
      actual_value: kpi.actual_value,
      formatted_target: kpi.formatted_target,
      formatted_actual: kpi.formatted_actual,
      achievement_percentage: kpi.achievement_percentage,
      achievement_status: kpi.achievement_status,
      measurement_unit: kpi.measurement_unit,
      period_start: kpi.period_start,
      period_end: kpi.period_end,
      period_duration_days: kpi.period_duration_days,
      elapsed_period_percentage: kpi.elapsed_period_percentage,
      expected_progress: kpi.expected_progress,
      progress_variance: kpi.progress_variance,
      status: kpi.status,
      is_overdue: kpi.is_overdue?,
      is_on_track: kpi.is_on_track?,
      days_until_period_end: kpi.days_until_period_end,
      can_be_completed: kpi.can_be_completed?,
      department_average: department_average,
      created_at: kpi.created_at,
      updated_at: kpi.updated_at
    }
  end

  def current_employee
    @current_employee ||= current_user.employee
  end

  def accessible_employee_ids
    employee = current_employee
    return Employee.pluck(:id) if current_user.admin? || current_user.super_admin?
    
    # Include self and subordinates
    ([employee.id] + employee.all_subordinates.pluck(:id)).uniq
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end 