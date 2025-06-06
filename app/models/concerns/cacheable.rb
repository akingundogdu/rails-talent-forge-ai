module Cacheable
  extend ActiveSupport::Concern

  class_methods do
    def cache_key_for(id)
      ["#{model_name.cache_key}", id]
    end

    def cached_find(id)
      Rails.cache.fetch([name.underscore.pluralize, id], expires_in: 1.hour) do
        find(id)
      end
    end

    def cached_where(conditions)
      cache_key = ["#{model_name.cache_key}", 'where', conditions.to_s]
      
      CacheService.fetch(cache_key, expires_in: 1.hour) do
        where(conditions).to_a
      end
    end

    def cached_count
      CacheService.fetch("#{model_name.cache_key}:count", expires_in: 1.hour) do
        count
      end
    end
  end

  def cache_key
    self.class.cache_key_for(id)
  end

  def clear_cache
    CacheService.delete(cache_key)
  end

  def cache_self(expires_in: 12.hours)
    CacheService.write(cache_key, self, expires_in: expires_in)
  end

  private

  def touch_cache
    clear_cache
    cache_self
  end
end 