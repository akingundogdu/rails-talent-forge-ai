class CacheService
  class << self
    def cache_key_for(resource, identifier = nil)
      key = "#{resource.class.name.underscore}"
      key += ":#{identifier}" if identifier.present?
      key
    end

    def cache_key_with_version(resource)
      if resource.is_a?(ApplicationRecord)
        resource.cache_key_with_version
      else
        cache_key_for(resource)
      end
    end

    def fetch_department_tree(department)
      Rails.cache.fetch(cache_key_for(department, "tree"), expires_in: 1.hour) do
        department.subtree
      end
    end

    def fetch_org_chart(department)
      Rails.cache.fetch(cache_key_for(department, "org_chart"), expires_in: 1.hour) do
        {
          department: department,
          positions: department.positions.includes(:parent_position, :employees),
          employees: department.employees.includes(:position, :manager)
        }
      end
    end

    def fetch_position_hierarchy(position)
      Rails.cache.fetch(cache_key_for(position, "hierarchy"), expires_in: 1.hour) do
        position.hierarchy
      end
    end

    def fetch_employee_subordinates(employee)
      Rails.cache.fetch(cache_key_for(employee, "subordinates"), expires_in: 1.hour) do
        employee.subordinates_tree
      end
    end

    def invalidate_department_caches(department)
      Rails.cache.delete_matched("department:#{department.id}*")
      department.ancestors.each do |ancestor|
        Rails.cache.delete_matched("department:#{ancestor.id}*")
      end
    end

    def invalidate_position_caches(position)
      Rails.cache.delete_matched("position:#{position.id}*")
      position.ancestors.each do |ancestor|
        Rails.cache.delete_matched("position:#{ancestor.id}*")
      end
      position.department.tap do |dept|
        Rails.cache.delete_matched("department:#{dept.id}*")
      end
    end

    def invalidate_employee_caches(employee)
      Rails.cache.delete_matched("employee:#{employee.id}*")
      employee.ancestors.each do |ancestor|
        Rails.cache.delete_matched("employee:#{ancestor.id}*")
      end
      employee.position.tap do |pos|
        Rails.cache.delete_matched("position:#{pos.id}*")
      end
      employee.department.tap do |dept|
        Rails.cache.delete_matched("department:#{dept.id}*")
      end
    end

    def clear_all_caches
      Rails.cache.clear
    end

    def fetch(key, expires_in: 1.hour, force: false, &block)
      return yield if force

      Rails.cache.fetch(normalized_key(key), expires_in: expires_in, &block)
    rescue Redis::BaseError => e
      Rails.logger.error("Redis cache error for key '#{key}': #{e.message}")
      yield
    end

    def write(key, value, expires_in: 1.hour)
      Rails.cache.write(normalized_key(key), value, expires_in: expires_in)
    rescue Redis::BaseError => e
      Rails.logger.error("Redis cache write error for key '#{key}': #{e.message}")
      false
    end

    def read(key)
      Rails.cache.read(normalized_key(key))
    rescue Redis::BaseError => e
      Rails.logger.error("Redis cache read error for key '#{key}': #{e.message}")
      nil
    end

    def delete(key)
      Rails.cache.delete(normalized_key(key))
    rescue Redis::BaseError => e
      Rails.logger.error("Redis cache delete error for key '#{key}': #{e.message}")
      false
    end

    def delete_matched(pattern)
      Rails.cache.delete_matched(normalized_key(pattern))
    rescue Redis::BaseError => e
      Rails.logger.error("Redis cache delete_matched error for pattern '#{pattern}': #{e.message}")
      false
    end

    def exist?(key)
      Rails.cache.exist?(normalized_key(key))
    rescue Redis::BaseError => e
      Rails.logger.error("Redis cache exist? error for key '#{key}': #{e.message}")
      false
    end

    def clear
      Rails.cache.clear
    rescue Redis::BaseError => e
      Rails.logger.error("Redis cache clear error: #{e.message}")
      false
    end

    private

    def normalized_key(key)
      case key
      when String, Symbol
        key.to_s
      when Array
        key.map(&:to_s).join(':')
      else
        key.to_s
      end
    end
  end
end 