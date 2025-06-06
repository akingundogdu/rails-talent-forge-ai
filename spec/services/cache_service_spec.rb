# frozen_string_literal: true

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
    it 'generates cache key for resource without identifier' do
      key = described_class.cache_key_for(department)
      expect(key).to eq('department')
    end

    it 'generates cache key for resource with identifier' do
      key = described_class.cache_key_for(department, 'tree')
      expect(key).to eq('department:tree')
    end

    it 'handles nil identifier' do
      key = described_class.cache_key_for(department, nil)
      expect(key).to eq('department')
    end

    it 'handles empty string identifier' do
      key = described_class.cache_key_for(department, '')
      expect(key).to eq('department')
    end
  end

  describe '.cache_key_with_version' do
    it 'returns cache_key_with_version for ApplicationRecord' do
      allow(department).to receive(:cache_key_with_version).and_return('department/1-20240101120000')
      key = described_class.cache_key_with_version(department)
      expect(key).to eq('department/1-20240101120000')
    end

    it 'returns cache_key_for for non-ApplicationRecord' do
      key = described_class.cache_key_with_version('string_resource')
      expect(key).to eq('string')
    end
  end

  describe '.fetch_department_tree' do
    it 'fetches and caches department tree' do
      expect(Rails.cache).to receive(:fetch)
        .with('department:tree', expires_in: 1.hour)
        .and_yield
      
      allow(department).to receive(:subtree).and_return([department])
      
      result = described_class.fetch_department_tree(department)
      expect(result).to eq([department])
    end
  end

  describe '.fetch_org_chart' do
    it 'fetches and caches org chart' do
      expect(Rails.cache).to receive(:fetch)
        .with('department:org_chart', expires_in: 1.hour)
        .and_yield
      
      allow(department).to receive(:positions).and_return(double(includes: [position]))
      allow(department).to receive(:employees).and_return(double(includes: [employee]))
      
      result = described_class.fetch_org_chart(department)
      expect(result[:department]).to eq(department)
      expect(result[:positions]).to eq([position])
      expect(result[:employees]).to eq([employee])
    end
  end

  describe '.fetch_position_hierarchy' do
    it 'fetches and caches position hierarchy' do
      expect(Rails.cache).to receive(:fetch)
        .with('position:hierarchy', expires_in: 1.hour)
        .and_yield
      
      allow(position).to receive(:hierarchy).and_return([position])
      
      result = described_class.fetch_position_hierarchy(position)
      expect(result).to eq([position])
    end
  end

  describe '.fetch_employee_subordinates' do
    it 'fetches and caches employee subordinates' do
      expect(Rails.cache).to receive(:fetch)
        .with('employee:subordinates', expires_in: 1.hour)
        .and_yield
      
      allow(employee).to receive(:subordinates_tree).and_return([employee])
      
      result = described_class.fetch_employee_subordinates(employee)
      expect(result).to eq([employee])
    end
  end

  describe 'cache invalidation' do
    describe '.invalidate_department_caches' do
      it 'deletes department cache pattern' do
        expect(Rails.cache).to receive(:delete_matched).with("department:#{department.id}*")
        
        described_class.invalidate_department_caches(department)
      end
    end

    describe '.invalidate_position_caches' do
      it 'deletes position and related department cache patterns' do
        expect(Rails.cache).to receive(:delete_matched).with("position:#{position.id}*")
        expect(Rails.cache).to receive(:delete_matched).with("department:#{position.department_id}*")
        
        described_class.invalidate_position_caches(position)
      end
    end

    describe '.invalidate_employee_caches' do
      it 'deletes employee, position and department cache patterns' do
        expect(Rails.cache).to receive(:delete_matched).with("employee:#{employee.id}*")
        expect(Rails.cache).to receive(:delete_matched).with("position:#{employee.position_id}*")
        expect(Rails.cache).to receive(:delete_matched).with("department:#{employee.position.department_id}*")
        
        described_class.invalidate_employee_caches(employee)
      end
    end

    describe '.clear_all_caches' do
      it 'clears all Rails cache' do
        expect(Rails.cache).to receive(:clear)
        
        described_class.clear_all_caches
      end
    end
  end

  describe '.fetch' do
    let(:test_key) { 'test:key' }
    let(:test_value) { 'test_value' }

    context 'when force is false' do
      it 'uses Rails cache fetch' do
        expect(Rails.cache).to receive(:fetch)
          .with('test:key', expires_in: 1.hour)
          .and_return(test_value)
        
        result = described_class.fetch(test_key) { test_value }
        expect(result).to eq(test_value)
      end

      it 'respects custom expires_in' do
        expect(Rails.cache).to receive(:fetch)
          .with('test:key', expires_in: 30.minutes)
          .and_return(test_value)
        
        described_class.fetch(test_key, expires_in: 30.minutes) { test_value }
      end

      it 'handles Redis errors gracefully' do
        allow(Rails.cache).to receive(:fetch).and_raise(Redis::BaseError, 'Redis connection failed')
        allow(Rails.logger).to receive(:error)
        
        result = described_class.fetch(test_key) { test_value }
        expect(result).to eq(test_value)
        expect(Rails.logger).to have_received(:error).with(/Redis cache error/)
      end
    end

    context 'when force is true' do
      it 'bypasses cache and executes block directly' do
        expect(Rails.cache).not_to receive(:fetch)
        
        result = described_class.fetch(test_key, force: true) { test_value }
        expect(result).to eq(test_value)
      end
    end
  end

  describe '.write' do
    let(:test_key) { 'test:key' }
    let(:test_value) { 'test_value' }

    it 'writes to Rails cache with normalized key' do
      expect(Rails.cache).to receive(:write)
        .with('test:key', test_value, expires_in: 1.hour)
        .and_return(true)
      
      result = described_class.write(test_key, test_value)
      expect(result).to be true
    end

    it 'respects custom expires_in' do
      expect(Rails.cache).to receive(:write)
        .with('test:key', test_value, expires_in: 30.minutes)
        .and_return(true)
      
      described_class.write(test_key, test_value, expires_in: 30.minutes)
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:write).and_raise(Redis::BaseError, 'Redis connection failed')
      allow(Rails.logger).to receive(:error)
      
      result = described_class.write(test_key, test_value)
      expect(result).to be false
      expect(Rails.logger).to have_received(:error).with(/Redis cache write error/)
    end
  end

  describe '.read' do
    let(:test_key) { 'test:key' }
    let(:test_value) { 'test_value' }

    it 'reads from Rails cache with normalized key' do
      expect(Rails.cache).to receive(:read)
        .with('test:key')
        .and_return(test_value)
      
      result = described_class.read(test_key)
      expect(result).to eq(test_value)
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:read).and_raise(Redis::BaseError, 'Redis connection failed')
      allow(Rails.logger).to receive(:error)
      
      result = described_class.read(test_key)
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error).with(/Redis cache read error/)
    end
  end

  describe '.delete' do
    let(:test_key) { 'test:key' }

    it 'deletes from Rails cache with normalized key' do
      expect(Rails.cache).to receive(:delete)
        .with('test:key')
        .and_return(true)
      
      result = described_class.delete(test_key)
      expect(result).to be true
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:delete).and_raise(Redis::BaseError, 'Redis connection failed')
      allow(Rails.logger).to receive(:error)
      
      result = described_class.delete(test_key)
      expect(result).to be false
      expect(Rails.logger).to have_received(:error).with(/Redis cache delete error/)
    end
  end

  describe '.delete_matched' do
    let(:test_pattern) { 'test:*' }

    it 'deletes matched keys from Rails cache with normalized pattern' do
      expect(Rails.cache).to receive(:delete_matched)
        .with('test:*')
        .and_return(true)
      
      result = described_class.delete_matched(test_pattern)
      expect(result).to be true
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:delete_matched).and_raise(Redis::BaseError, 'Redis connection failed')
      allow(Rails.logger).to receive(:error)
      
      result = described_class.delete_matched(test_pattern)
      expect(result).to be false
      expect(Rails.logger).to have_received(:error).with(/Redis cache delete_matched error/)
    end
  end

  describe '.exist?' do
    let(:test_key) { 'test:key' }

    it 'checks existence in Rails cache with normalized key' do
      expect(Rails.cache).to receive(:exist?)
        .with('test:key')
        .and_return(true)
      
      result = described_class.exist?(test_key)
      expect(result).to be true
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:exist?).and_raise(Redis::BaseError, 'Redis connection failed')
      allow(Rails.logger).to receive(:error)
      
      result = described_class.exist?(test_key)
      expect(result).to be false
      expect(Rails.logger).to have_received(:error).with(/Redis cache exist\? error/)
    end
  end

  describe '.clear' do
    it 'clears Rails cache' do
      expect(Rails.cache).to receive(:clear).and_return(true)
      
      result = described_class.clear
      expect(result).to be true
    end

    it 'handles Redis errors gracefully' do
      allow(Rails.cache).to receive(:clear).and_raise(Redis::BaseError, 'Redis connection failed')
      allow(Rails.logger).to receive(:error)
      
      result = described_class.clear
      expect(result).to be false
      expect(Rails.logger).to have_received(:error).with(/Redis cache clear error/)
    end
  end

  describe '.normalized_key (private method)' do
    it 'normalizes string keys' do
      key = described_class.send(:normalized_key, 'test_key')
      expect(key).to eq('test_key')
    end

    it 'normalizes symbol keys' do
      key = described_class.send(:normalized_key, :test_key)
      expect(key).to eq('test_key')
    end

    it 'normalizes array keys' do
      key = described_class.send(:normalized_key, ['test', 'key', 123])
      expect(key).to eq('test:key:123')
    end

    it 'normalizes other objects' do
      key = described_class.send(:normalized_key, 123)
      expect(key).to eq('123')
    end

    it 'handles complex array with mixed types' do
      key = described_class.send(:normalized_key, ['departments', 'org_chart', department.id])
      expect(key).to eq("departments:org_chart:#{department.id}")
    end
  end
end 