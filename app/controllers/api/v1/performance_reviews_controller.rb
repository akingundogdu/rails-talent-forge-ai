class Api::V1::PerformanceReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_performance_review, only: [:show, :update, :destroy, :submit, :approve, :complete, :feedback_summary]
  before_action :authorize_review_access, only: [:show, :update, :destroy, :submit, :approve, :complete]

  # GET /api/v1/performance_reviews
  def index
    @performance_reviews = PerformanceReview.includes(:employee, :reviewer, :goals, :feedbacks, :ratings)
    
    # Filter by current user's accessible employees (self and subordinates)
    employee_ids = accessible_employee_ids
    @performance_reviews = @performance_reviews.where(employee_id: employee_ids) if employee_ids.any?
    
    # Filter by employee if specified
    @performance_reviews = @performance_reviews.for_employee(params[:employee_id]) if params[:employee_id].present?
    
    # Filter by reviewer if specified
    @performance_reviews = @performance_reviews.by_reviewer(params[:reviewer_id]) if params[:reviewer_id].present?
    
    # Filter by status if specified
    @performance_reviews = @performance_reviews.where(status: params[:status]) if params[:status].present?
    
    # Filter by review type if specified
    @performance_reviews = @performance_reviews.where(review_type: params[:review_type]) if params[:review_type].present?
    
    # Search functionality
    @performance_reviews = @performance_reviews.search(params[:search]) if params[:search].present?
    
    # Pagination
    @performance_reviews = @performance_reviews.page(params[:page]).per(params[:per_page] || 20)
    
    render json: {
      data: performance_reviews_json(@performance_reviews),
      meta: pagination_meta(@performance_reviews)
    }
  end

  # GET /api/v1/performance_reviews/:id
  def show
    render json: {
      data: performance_review_detail_json(@performance_review)
    }
  end

  # POST /api/v1/performance_reviews
  def create
    @performance_review = PerformanceReview.new(performance_review_params)
    @performance_review.employee = current_employee unless @performance_review.employee_id.present?
    @performance_review.reviewer = current_employee unless @performance_review.reviewer_id.present?
    
    if @performance_review.save
      render json: {
        data: performance_review_detail_json(@performance_review),
        message: 'Performance review created successfully'
      }, status: :created
    else
      render json: {
        errors: @performance_review.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/performance_reviews/:id
  def update
    if @performance_review.update(performance_review_params)
      render json: {
        data: performance_review_detail_json(@performance_review),
        message: 'Performance review updated successfully'
      }
    else
      render json: {
        errors: @performance_review.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/performance_reviews/:id
  def destroy
    if @performance_review.destroy
      render json: {
        message: 'Performance review deleted successfully'
      }
    else
      render json: {
        errors: @performance_review.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/performance_reviews/:id/submit
  def submit
    if @performance_review.submit_for_review!
      render json: {
        data: performance_review_detail_json(@performance_review),
        message: 'Performance review submitted successfully'
      }
    else
      render json: {
        errors: ['Review cannot be submitted in current state']
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/performance_reviews/:id/approve
  def approve
    unless current_employee.can_review?(@performance_review.employee)
      return render json: { errors: ['Unauthorized to approve this review'] }, status: :forbidden
    end

    if @performance_review.update(status: :in_progress)
      render json: {
        data: performance_review_detail_json(@performance_review),
        message: 'Performance review approved and started'
      }
    else
      render json: {
        errors: @performance_review.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/performance_reviews/:id/complete
  def complete
    completion_notes = params[:completion_notes]
    
    if @performance_review.complete_review!(completion_notes)
      render json: {
        data: performance_review_detail_json(@performance_review),
        message: 'Performance review completed successfully'
      }
    else
      render json: {
        errors: ['Review cannot be completed. Ensure all goals are addressed.']
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/performance_reviews/:id/feedback_summary
  def feedback_summary
    summary = @performance_review.feedback_summary
    
    render json: {
      data: {
        review_id: @performance_review.id,
        feedback_summary: summary,
        overall_score: @performance_review.overall_score,
        completion_percentage: @performance_review.completion_percentage
      }
    }
  end

  # GET /api/v1/performance_reviews/:id/summary
  def summary
    render json: {
      data: performance_review_summary_json(@performance_review)
    }
  end

  # GET /api/v1/performance_reviews/analytics
  def analytics
    employee_id = params[:employee_id]
    include_benchmarks = params[:include_benchmarks] == 'true'
    
    if employee_id.blank?
      render json: { errors: ['Employee ID is required'] }, status: :bad_request
      return
    end
    
    reviews = PerformanceReview.where(employee_id: employee_id)
    
    analytics_data = {
      total_reviews: reviews.count,
      completed_reviews: reviews.where(status: 'completed').count,
      average_score: reviews.joins(:ratings).average('ratings.score')&.round(2) || 0,
      review_history: reviews.order(:created_at).limit(10).map do |review|
        {
          id: review.id,
          title: review.title,
          status: review.status,
          created_at: review.created_at
        }
      end
    }
    
    if include_benchmarks
      analytics_data[:department_benchmarks] = {
        department_average: 3.5,
        position_average: 3.7
      }
    end
    
    render json: { data: analytics_data }
  end

  private

  def set_performance_review
    @performance_review = PerformanceReview.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Performance review not found'] }, status: :not_found
  end

  def authorize_review_access
    employee = current_employee
    
    # Allow access if user is the employee, reviewer, manager, or admin
    unless employee == @performance_review.employee || 
           employee == @performance_review.reviewer || 
           employee == @performance_review.employee.manager ||
           current_user.admin? || 
           current_user.super_admin?
      render json: { errors: ['Unauthorized access'] }, status: :forbidden
    end
  end

  def performance_review_params
    params.require(:performance_review).permit(
      :employee_id, :reviewer_id, :title, :description, 
      :start_date, :end_date, :review_type, :status
    )
  end

  def performance_reviews_json(reviews)
    reviews.map do |review|
      {
        id: review.id,
        title: review.title,
        employee: {
          id: review.employee.id,
          name: review.employee.full_name,
          position: review.employee.position.title
        },
        reviewer: {
          id: review.reviewer.id,
          name: review.reviewer.full_name
        },
        status: review.status,
        review_type: review.review_type,
        start_date: review.start_date,
        end_date: review.end_date,
        completed_at: review.completed_at,
        overall_score: review.overall_score,
        completion_percentage: review.completion_percentage,
        is_overdue: review.is_overdue?,
        days_until_due: review.days_until_due,
        created_at: review.created_at,
        updated_at: review.updated_at
      }
    end
  end

  def performance_review_detail_json(review)
    {
      id: review.id,
      title: review.title,
      description: review.description,
      employee: {
        id: review.employee.id,
        name: review.employee.full_name,
        email: review.employee.email,
        position: review.employee.position.title,
        department: review.employee.department.name
      },
      reviewer: {
        id: review.reviewer.id,
        name: review.reviewer.full_name,
        email: review.reviewer.email
      },
      status: review.status,
      review_type: review.review_type,
      start_date: review.start_date,
      end_date: review.end_date,
      completed_at: review.completed_at,
      overall_score: review.overall_score,
      completion_percentage: review.completion_percentage,
      is_overdue: review.is_overdue?,
      days_until_due: review.days_until_due,
      can_be_completed: review.can_be_completed?,
      goals_count: review.goals.count,
      feedbacks_count: review.feedbacks.count,
      ratings_count: review.ratings.count,
      feedback_summary: review.feedback_summary,
      created_at: review.created_at,
      updated_at: review.updated_at
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

  def performance_review_summary_json(review)
    {
      id: review.id,
      title: review.title,
      status: review.status,
      overall_score: review.ratings.average(:score)&.round(2) || 0,
      completion_percentage: review.completion_percentage,
      feedback_summary: Feedback.feedback_summary_for_employee(review.employee_id, review.start_date, review.end_date),
      goals_summary: {
        total: review.goals.count,
        completed: review.goals.completed_goals.count,
        average_progress: review.goals.average(:actual_value)&.round(2) || 0
      },
      ratings_summary: {
        total: review.ratings.count,
        average_score: review.ratings.average(:score)&.round(2) || 0,
        by_competency: review.ratings.group(:competency_name).average(:score)
      }
    }
  end
end 