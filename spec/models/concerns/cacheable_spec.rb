require 'rails_helper'

RSpec.describe Cacheable do
  let(:department) { create(:department) }

  describe '.cached_find' do
    it 'caches the found record' do
      expect(CacheService).to receive(:fetch)
        .with(Department.cache_key_for(department.id), expires_in: 12.hours)
        .and_yield

      Department.cached_find(department.id)
    end

    it 'returns the correct record' do
      found_department = Department.cached_find(department.id)
      expect(found_department).to eq(department)
    end
  end

  describe '.cached_where' do
    let!(:test_department) { create(:department, name: 'Unique Test Department') }
    let(:conditions) { { name: 'Unique Test Department' } }

    it 'caches the query results' do
      cache_key = ['Department', 'where', conditions.to_s]
      
      expect(CacheService).to receive(:fetch)
        .with(cache_key, expires_in: 1.hour)
        .and_yield

      Department.cached_where(conditions)
    end

    it 'returns the correct records' do
      results = Department.cached_where(conditions)
      expect(results.length).to eq(1)
      expect(results.first.name).to eq('Unique Test Department')
    end
  end

  describe '.cached_count' do
    before { create_list(:department, 3) }

    it 'caches the count' do
      expect(CacheService).to receive(:fetch)
        .with('Department:count', expires_in: 1.hour)
        .and_yield

      Department.cached_count
    end

    it 'returns the correct count' do
      expect(Department.cached_count).to eq(3)
    end
  end

  describe '#cache_key' do
    it 'returns the correct cache key' do
      expect(department.cache_key).to eq(['Department', department.id])
    end
  end

  describe '#clear_cache' do
    it 'deletes the cache entry' do
      expect(CacheService).to receive(:delete).with(department.cache_key)
      department.clear_cache
    end
  end

  describe '#cache_self' do
    it 'writes the record to cache' do
      expect(CacheService).to receive(:write)
        .with(department.cache_key, department, expires_in: 12.hours)
      
      department.cache_self
    end

    it 'accepts custom expiration time' do
      custom_expires_in = 2.hours
      
      expect(CacheService).to receive(:write)
        .with(department.cache_key, department, expires_in: custom_expires_in)
      
      department.cache_self(expires_in: custom_expires_in)
    end
  end
end 