require 'rails_helper'

RSpec.describe CacheService, type: :service do
  let(:department) { create(:department) }
  let(:position) { create(:position, department: department) }
  let(:user) { create(:user) }
  let(:employee) { create(:employee, position: position, user: user) }

  let(:key) { 'test_key' }
  let(:value) { 'test_value' }
  let(:expires_in) { 1.hour }

  before do
    allow(Rails.cache).to receive(:fetch).and_yield
    allow(Rails.cache).to receive(:delete_matched)
    allow(Rails.logger).to receive(:error)
  end

  describe '.cache_key_for' do
    it 'generates correct cache key for resource' do
      expect(described_class.cache_key_for(department)).to eq('department')
      expect(described_class.cache_key_for(department, 'tree')).to eq('department:tree')
    end
  end

  describe '.cache_key_with_version' do
    it 'returns cache key with version for ActiveRecord objects' do
      expect(described_class.cache_key_with_version(department)).to eq(department.cache_key_with_version)
    end

    it 'returns simple cache key for non-ActiveRecord objects' do
      object = double('CustomObject', class: OpenStruct)
      expect(described_class.cache_key_with_version(object)).to eq('open_struct')
    end
  end

  describe '.fetch_department_tree' do
    it 'caches and returns department tree' do
      result = described_class.fetch_department_tree(department)
      expect(result).to be_a(ActiveRecord::Relation)
      expect(Rails.cache).to have_received(:fetch)
    end
  end

  describe '.fetch_org_chart' do
    it 'caches and returns organization chart' do
      result = described_class.fetch_org_chart(department)
      expect(result[:department]).to eq(department)
      expect(result[:positions]).to be_a(ActiveRecord::Relation)
      expect(result[:employees]).to be_a(ActiveRecord::Relation)
      expect(Rails.cache).to have_received(:fetch)
    end
  end

  describe '.fetch_position_hierarchy' do
    it 'caches and returns position hierarchy' do
      result = described_class.fetch_position_hierarchy(position)
      expect(result).to be_a(ActiveRecord::Relation)
      expect(Rails.cache).to have_received(:fetch)
    end
  end

  describe '.fetch_employee_subordinates' do
    it 'caches and returns employee subordinates' do
      result = described_class.fetch_employee_subordinates(employee)
      expect(result).to be_a(ActiveRecord::Relation)
      expect(Rails.cache).to have_received(:fetch)
    end
  end

  describe 'cache invalidation' do
    describe '.invalidate_department_caches' do
      it 'invalidates department and ancestor caches' do
        described_class.invalidate_department_caches(department)
        expect(Rails.cache).to have_received(:delete_matched).with("department:#{department.id}*")
      end
    end

    describe '.invalidate_position_caches' do
      it 'invalidates position, ancestor, and department caches' do
        described_class.invalidate_position_caches(position)
        expect(Rails.cache).to have_received(:delete_matched).with("position:#{position.id}*")
        expect(Rails.cache).to have_received(:delete_matched).with("department:#{position.department_id}*")
      end
    end

    describe '.invalidate_employee_caches' do
      it 'invalidates employee, ancestor, position, and department caches' do
        described_class.invalidate_employee_caches(employee)
        expect(Rails.cache).to have_received(:delete_matched).with("employee:#{employee.id}*")
        expect(Rails.cache).to have_received(:delete_matched).with("position:#{employee.position_id}*")
        expect(Rails.cache).to have_received(:delete_matched).with("department:#{employee.position.department_id}*")
      end
    end

    describe '.clear_all_caches' do
      it 'clears all caches' do
        allow(Rails.cache).to receive(:clear)
        described_class.clear_all_caches
        expect(Rails.cache).to have_received(:clear)
      end
    end
  end

  describe '.fetch' do
    it 'fetches value from cache' do
      expect(Rails.cache).to receive(:fetch)
        .with(key, expires_in: expires_in)
        .and_return(value)

      result = described_class.fetch(key, expires_in: expires_in) { value }
      expect(result).to eq(value)
    end

    it 'yields block when force is true' do
      expect(Rails.cache).not_to receive(:fetch)

      result = described_class.fetch(key, force: true) { value }
      expect(result).to eq(value)
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:fetch).and_raise(Redis::BaseError)

      result = described_class.fetch(key) { value }
      expect(result).to eq(value)
    end
  end

  describe '.write' do
    it 'writes value to cache' do
      expect(Rails.cache).to receive(:write)
        .with(key, value, expires_in: expires_in)
        .and_return(true)

      result = described_class.write(key, value, expires_in: expires_in)
      expect(result).to be true
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:write).and_raise(Redis::BaseError)

      result = described_class.write(key, value)
      expect(result).to be false
    end
  end

  describe '.read' do
    it 'reads value from cache' do
      expect(Rails.cache).to receive(:read)
        .with(key)
        .and_return(value)

      result = described_class.read(key)
      expect(result).to eq(value)
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:read).and_raise(Redis::BaseError)

      result = described_class.read(key)
      expect(result).to be_nil
    end
  end

  describe '.delete' do
    it 'deletes value from cache' do
      expect(Rails.cache).to receive(:delete)
        .with(key)
        .and_return(true)

      result = described_class.delete(key)
      expect(result).to be true
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:delete).and_raise(Redis::BaseError)

      result = described_class.delete(key)
      expect(result).to be false
    end
  end

  describe '.delete_matched' do
    it 'deletes matched keys from cache' do
      expect(Rails.cache).to receive(:delete_matched)
        .with(key)
        .and_return(true)

      result = described_class.delete_matched(key)
      expect(result).to be true
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:delete_matched).and_raise(Redis::BaseError)

      result = described_class.delete_matched(key)
      expect(result).to be false
    end
  end

  describe '.exist?' do
    it 'checks if key exists in cache' do
      expect(Rails.cache).to receive(:exist?)
        .with(key)
        .and_return(true)

      result = described_class.exist?(key)
      expect(result).to be true
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:exist?).and_raise(Redis::BaseError)

      result = described_class.exist?(key)
      expect(result).to be false
    end
  end

  describe '.clear' do
    it 'clears the cache' do
      expect(Rails.cache).to receive(:clear)
        .and_return(true)

      result = described_class.clear
      expect(result).to be true
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:clear).and_raise(Redis::BaseError)

      result = described_class.clear
      expect(result).to be false
    end
  end
end 