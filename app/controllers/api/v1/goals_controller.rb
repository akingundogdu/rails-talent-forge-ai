class Api::V1::GoalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_goal, only: [:show, :update, :destroy, :update_progress, :complete, :pause, :resume, :cancel]
  before_action :authorize_goal_access, only: [:show, :update, :destroy, :update_progress, :complete, :pause, :resume, :cancel]

  # GET /api/v1/goals
  def index
    @goals = Goal.includes(:employee, :performance_review)
    
    # Filter by current user's accessible employees (self and subordinates)
    employee_ids = accessible_employee_ids
    @goals = @goals.where(employee_id: employee_ids) if employee_ids.any?
    
    # Filter by employee
    @goals = @goals.for_employee(params[:employee_id]) if params[:employee_id].present?
    
    # Filter by performance review
    @goals = @goals.for_review(params[:performance_review_id]) if params[:performance_review_id].present?
    
    # Filter by status
    @goals = @goals.where(status: params[:status]) if params[:status].present?
    
    # Filter by priority
    @goals = @goals.by_priority(params[:priority]) if params[:priority].present?
    
    # Filter standalone goals (not linked to reviews)
    @goals = @goals.standalone if params[:standalone] == 'true'
    
    # Search functionality
    @goals = @goals.search(params[:search]) if params[:search].present?
    
    # Pagination
    @goals = @goals.page(params[:page]).per(params[:per_page] || 20)
    
    render json: {
      data: goals_json(@goals),
      meta: pagination_meta(@goals)
    }
  end

  # GET /api/v1/goals/:id
  def show
    render json: {
      data: goal_detail_json(@goal)
    }
  end

  # POST /api/v1/goals
  def create
    @goal = Goal.new(goal_params)
    @goal.employee = current_employee
    
    if @goal.save
      render json: {
        data: goal_detail_json(@goal),
        message: 'Goal created successfully'
      }, status: :created
    else
      render json: {
        errors: @goal.errors.full_messages,
        smart_violations: @goal.smart_violations
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/goals/:id
  def update
    if @goal.update(goal_params)
      render json: {
        data: goal_detail_json(@goal),
        message: 'Goal updated successfully'
      }
    else
      render json: {
        errors: @goal.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/goals/:id
  def destroy
    if @goal.destroy
      render json: {
        message: 'Goal deleted successfully'
      }
    else
      render json: {
        errors: @goal.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/goals/:id/update_progress
  def update_progress
    actual_value = params[:actual_value]
    notes = params[:notes]
    
    if @goal.update_progress!(actual_value, notes)
      render json: {
        data: goal_detail_json(@goal),
        message: 'Goal progress updated successfully'
      }
    else
      render json: {
        errors: @goal.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/goals/:id/complete
  def complete
    completion_notes = params[:completion_notes]
    
    if @goal.mark_completed!(completion_notes)
      render json: {
        data: goal_detail_json(@goal),
        message: 'Goal marked as completed successfully'
      }
    else
      render json: {
        errors: ['Goal cannot be completed in current state']
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/goals/:id/pause
  def pause
    reason = params[:reason]
    
    if @goal.pause!(reason)
      render json: {
        data: goal_detail_json(@goal),
        message: 'Goal paused successfully'
      }
    else
      render json: {
        errors: ['Goal cannot be paused in current state']
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/goals/:id/resume
  def resume
    notes = params[:notes]
    
    if @goal.resume!(notes)
      render json: {
        data: goal_detail_json(@goal),
        message: 'Goal resumed successfully'
      }
    else
      render json: {
        errors: ['Goal cannot be resumed in current state']
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/goals/:id/cancel
  def cancel
    reason = params[:reason]
    
    if @goal.cancel!(reason)
      render json: {
        data: goal_detail_json(@goal),
        message: 'Goal cancelled successfully'
      }
    else
      render json: {
        errors: ['Goal cannot be cancelled in current state']
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/goals/bulk_update_progress
  def bulk_update_progress
    goals_params = params[:goals] || []
    
    begin
      Goal.transaction do
        goals_params.each do |goal_update|
          goal = Goal.find(goal_update[:id])
          
          # Check authorization for each goal
          employee = current_employee
          unless employee == goal.employee || 
                 employee == goal.employee.manager ||
                 current_user.admin? || 
                 current_user.super_admin?
            raise StandardError, "Unauthorized access to goal #{goal.id}"
          end
          
          goal.update!(actual_value: goal_update[:actual_value])
        end
      end
      
      render json: {
        message: 'Goals updated successfully'
      }
    rescue StandardError => e
      render json: {
        errors: [e.message]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/goals/overdue
  def overdue
    @overdue_goals = Goal.overdue_goals.includes(:employee)
    
    # Filter by current user's accessible employees
    employee_ids = accessible_employee_ids
    @overdue_goals = @overdue_goals.where(employee_id: employee_ids) if employee_ids.any?
    
    render json: {
      data: goals_json(@overdue_goals),
      meta: {
        total_count: @overdue_goals.count,
        message: 'Overdue goals requiring attention'
      }
    }
  end

  # GET /api/v1/goals/due_soon
  def due_soon
    days = params[:days]&.to_i || 7
    @due_soon_goals = Goal.due_soon(days).includes(:employee)
    
    # Filter by current user's accessible employees
    employee_ids = accessible_employee_ids
    @due_soon_goals = @due_soon_goals.where(employee_id: employee_ids) if employee_ids.any?
    
    render json: {
      data: goals_json(@due_soon_goals),
      meta: {
        total_count: @due_soon_goals.count,
        days: days,
        message: "Goals due within #{days} days"
      }
    }
  end

  # GET /api/v1/goals/analytics
  def analytics
    employee_ids = accessible_employee_ids
    goals = Goal.where(employee_id: employee_ids)
    
    render json: {
      data: {
        total_goals: goals.count,
        completed_goals: goals.completed_goals.count,
        active_goals: goals.active_goals.count,
        overdue_goals: goals.overdue_goals.count,
        completion_rate: goals.count > 0 ? (goals.completed_goals.count.to_f / goals.count * 100).round(2) : 0,
        average_progress: goals.active_goals.average(:actual_value)&.round(2) || 0,
        goals_by_priority: goals.group(:priority).count,
        goals_by_status: goals.group(:status).count
      }
    }
  end

  private

  def set_goal
    @goal = Goal.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Goal not found'] }, status: :not_found
  end

  def authorize_goal_access
    employee = current_employee
    
    # Allow access if user is the goal owner, manager, or admin
    unless employee == @goal.employee || 
           employee == @goal.employee.manager ||
           current_user.admin? || 
           current_user.super_admin?
      render json: { errors: ['Unauthorized access'] }, status: :forbidden
    end
  end

  def goal_params
    params.require(:goal).permit(
      :employee_id, :performance_review_id, :title, :description,
      :target_value, :actual_value, :status, :priority, :due_date
    )
  end

  def goals_json(goals)
    goals.map do |goal|
      {
        id: goal.id,
        title: goal.title,
        description: goal.description,
        employee: {
          id: goal.employee.id,
          name: goal.employee.full_name,
          position: goal.employee.position.title
        },
        performance_review_id: goal.performance_review_id,
        target_value: goal.target_value,
        actual_value: goal.actual_value,
        completion_percentage: goal.completion_percentage,
        status: goal.status,
        priority: goal.priority,
        due_date: goal.due_date,
        completed_at: goal.completed_at,
        is_overdue: goal.is_overdue?,
        days_until_due: goal.days_until_due,
        progress_status: goal.progress_status,
        smart_score: goal.smart_score,
        created_at: goal.created_at,
        updated_at: goal.updated_at
      }
    end
  end

  def goal_detail_json(goal)
    {
      id: goal.id,
      title: goal.title,
      description: goal.description,
      employee: {
        id: goal.employee.id,
        name: goal.employee.full_name,
        email: goal.employee.email,
        position: goal.employee.position.title,
        department: goal.employee.department.name
      },
      performance_review: goal.performance_review ? {
        id: goal.performance_review.id,
        title: goal.performance_review.title,
        status: goal.performance_review.status
      } : nil,
      target_value: goal.target_value,
      actual_value: goal.actual_value,
      completion_percentage: goal.completion_percentage,
      expected_progress_percentage: goal.expected_progress_percentage,
      status: goal.status,
      priority: goal.priority,
      due_date: goal.due_date,
      completed_at: goal.completed_at,
      is_overdue: goal.is_overdue?,
      days_until_due: goal.days_until_due,
      days_overdue: goal.days_overdue,
      progress_status: goal.progress_status,
      smart_criteria: goal.is_smart_goal?,
      smart_compliant: goal.smart_compliant?,
      smart_score: goal.smart_score,
      created_at: goal.created_at,
      updated_at: goal.updated_at
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