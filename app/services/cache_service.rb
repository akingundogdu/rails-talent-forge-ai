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
    end

    def invalidate_position_caches(position)
      Rails.cache.delete_matched("position:#{position.id}*")
      Rails.cache.delete_matched("department:#{position.department_id}*")
    end

    def invalidate_employee_caches(employee)
      Rails.cache.delete_matched("employee:#{employee.id}*")
      Rails.cache.delete_matched("position:#{employee.position_id}*")
      Rails.cache.delete_matched("department:#{employee.position.department_id}*")
    end

    # Performance Management Cache Methods
    def fetch_performance_summary(employee_id)
      Rails.cache.fetch("performance:summary:#{employee_id}", expires_in: 1.hour) do
        employee = Employee.find(employee_id)
        {
          current_review: employee.current_performance_review,
          active_goals: employee.active_goals.count,
          overdue_goals: employee.overdue_goals.count,
          goal_completion_rate: employee.goal_completion_rate,
          kpi_achievement: employee.kpi_achievement_average,
          feedback_summary: employee.feedback_summary(6)
        }
      end
    end

    def fetch_department_performance_metrics(department_id)
      Rails.cache.fetch("performance:department:#{department_id}", expires_in: 2.hours) do
        employee_ids = Employee.joins(:position).where(positions: { department_id: department_id }).pluck(:id)
        
        {
          total_employees: employee_ids.count,
          active_reviews: PerformanceReview.where(employee_id: employee_ids, status: :in_progress).count,
          completed_reviews: PerformanceReview.where(employee_id: employee_ids, status: :completed).count,
          average_goal_completion: Goal.where(employee_id: employee_ids).completed_goals.count.to_f / Goal.where(employee_id: employee_ids).count * 100,
          kpi_performance: Kpi.department_performance_summary(department_id, 3.months.ago, Date.current)
        }
      end
    end

    def fetch_goal_analytics(employee_id)
      Rails.cache.fetch("goals:analytics:#{employee_id}", expires_in: 1.hour) do
        goals = Goal.for_employee(employee_id)
        
        {
          total_goals: goals.count,
          active_goals: goals.active_goals.count,
          completed_goals: goals.completed_goals.count,
          overdue_goals: goals.overdue_goals.count,
          completion_rate: goals.completed_goals.count.to_f / goals.count * 100,
          by_priority: goals.group(:priority).count,
          average_progress: goals.active_goals.average(:actual_value)&.round(2) || 0
        }
      end
    end

    def fetch_kpi_dashboard(employee_id, period_months = 3)
      Rails.cache.fetch("kpi:dashboard:#{employee_id}:#{period_months}", expires_in: 30.minutes) do
        period_start = period_months.months.ago
        kpis = Kpi.for_employee(employee_id).in_period(period_start, Date.current)
        
        {
          current_kpis: kpis.current_period.count,
          achievement_percentage: kpis.average('actual_value / target_value * 100')&.round(2) || 0,
          by_status: kpis.group(:status).count,
          by_measurement_unit: kpis.group(:measurement_unit).count,
          trending_data: Kpi.trending_analysis(employee_id, 'Sales Performance', period_months)
        }
      end
    end

    def invalidate_performance_caches(employee_id)
      Rails.cache.delete_matched("performance:*:#{employee_id}*")
      Rails.cache.delete_matched("goals:*:#{employee_id}*")
      Rails.cache.delete_matched("kpi:*:#{employee_id}*")
      Rails.cache.delete_matched("feedback:*:#{employee_id}*")
      
      # Also invalidate department caches if needed
      employee = Employee.find_by(id: employee_id)
      if employee&.department
        Rails.cache.delete_matched("performance:department:#{employee.department.id}*")
      end
    end

    def invalidate_goal_caches(employee_id)
      Rails.cache.delete_matched("goals:*:#{employee_id}*")
      Rails.cache.delete_matched("performance:summary:#{employee_id}*")
    end

    def invalidate_kpi_caches(employee_id, position_id = nil)
      Rails.cache.delete_matched("kpi:*:#{employee_id}*")
      Rails.cache.delete_matched("performance:summary:#{employee_id}*")
      
      if position_id
        Rails.cache.delete_matched("kpi:position:#{position_id}*")
      end
    end

    def invalidate_feedback_caches(receiver_id, giver_id = nil)
      Rails.cache.delete_matched("feedback:*:#{receiver_id}*")
      Rails.cache.delete_matched("performance:summary:#{receiver_id}*")
      
      if giver_id
        Rails.cache.delete_matched("feedback:given:#{giver_id}*")
      end
    end

    def invalidate_review_caches(performance_review_id)
      review = PerformanceReview.find_by(id: performance_review_id)
      return unless review
      
      invalidate_performance_caches(review.employee_id)
      Rails.cache.delete_matched("review:#{performance_review_id}*")
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