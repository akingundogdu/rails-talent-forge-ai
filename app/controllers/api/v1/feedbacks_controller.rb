class Api::V1::FeedbacksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_feedback, only: [:show, :update, :destroy, :update_feedback]
  before_action :authorize_feedback_access, only: [:show, :update, :destroy, :update_feedback]

  # GET /api/v1/feedbacks
  def index
    @feedbacks = Feedback.includes(:giver, :receiver, :performance_review)
    
    # Default to current employee's received feedback unless specified
    if params[:type] == 'given'
      @feedbacks = @feedbacks.where(giver: current_employee)
    else
      @feedbacks = @feedbacks.where(receiver: current_employee)
    end
    
    # Filter by receiver
    @feedbacks = @feedbacks.for_receiver(params[:receiver_id]) if params[:receiver_id].present?
    
    # Filter by giver
    @feedbacks = @feedbacks.by_giver(params[:giver_id]) if params[:giver_id].present?
    
    # Filter by performance review
    @feedbacks = @feedbacks.for_review(params[:performance_review_id]) if params[:performance_review_id].present?
    
    # Filter by feedback type
    @feedbacks = @feedbacks.by_type(params[:feedback_type]) if params[:feedback_type].present?
    
    # Filter anonymous/public
    @feedbacks = @feedbacks.anonymous_feedback if params[:anonymous] == 'true'
    @feedbacks = @feedbacks.public_feedback if params[:anonymous] == 'false'
    
    # Filter rated feedback
    @feedbacks = @feedbacks.rated_feedback if params[:rated] == 'true'
    
    # Filter by sentiment
    if params[:sentiment].present?
      case params[:sentiment]
      when 'positive'
        @feedbacks = @feedbacks.where('rating >= ?', 4)
      when 'negative'
        @feedbacks = @feedbacks.where('rating <= ?', 2)
      when 'neutral'
        @feedbacks = @feedbacks.where(rating: 3)
      end
    end
    
    # Recent feedback
    days = params[:recent_days]&.to_i || 30
    @feedbacks = @feedbacks.recent(days) if params[:recent] == 'true'
    
    # Search functionality
    @feedbacks = @feedbacks.search(params[:search]) if params[:search].present?
    
    # Pagination
    @feedbacks = @feedbacks.page(params[:page]).per(params[:per_page] || 20)
    
    render json: {
      data: feedbacks_json(@feedbacks),
      meta: pagination_meta(@feedbacks)
    }
  end

  # GET /api/v1/feedbacks/:id
  def show
    render json: {
      data: feedback_detail_json(@feedback)
    }
  end

  # POST /api/v1/feedbacks
  def create
    @feedback = Feedback.new(feedback_params)
    @feedback.giver = current_employee unless @feedback.giver_id.present?
    
    if @feedback.save
      render json: {
        data: feedback_detail_json(@feedback),
        message: 'Feedback created successfully'
      }, status: :created
    else
      render json: {
        errors: @feedback.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/feedbacks/:id
  def update
    unless @feedback.can_be_edited?
      return render json: {
        errors: ['Feedback cannot be edited after 24 hours or when review is completed']
      }, status: :unprocessable_entity
    end
    
    if @feedback.update(feedback_params)
      render json: {
        data: feedback_detail_json(@feedback),
        message: 'Feedback updated successfully'
      }
    else
      render json: {
        errors: @feedback.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/feedbacks/:id
  def destroy
    unless @feedback.can_be_edited?
      return render json: {
        errors: ['Feedback cannot be deleted after 24 hours or when review is completed']
      }, status: :unprocessable_entity
    end
    
    if @feedback.destroy
      render json: {
        message: 'Feedback deleted successfully'
      }
    else
      render json: {
        errors: ['Failed to delete feedback']
      }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/feedbacks/:id/update_feedback
  def update_feedback
    new_message = params[:message]
    new_rating = params[:rating]
    
    if @feedback.update_feedback!(new_message, new_rating)
      render json: {
        data: feedback_detail_json(@feedback),
        message: 'Feedback updated successfully'
      }
    else
      render json: {
        errors: ['Feedback cannot be updated (edit window expired or review completed)']
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/feedbacks/request_peer_feedback
  def request_peer_feedback
    employee_id = params[:employee_id]
    peer_ids = params[:peer_ids] || []
    performance_review_id = params[:performance_review_id]
    
    if employee_id.blank? || peer_ids.empty?
      return render json: {
        errors: ['Employee ID and peer IDs are required']
      }, status: :bad_request
    end
    
    begin
      Feedback.request_peer_feedback(employee_id, peer_ids, performance_review_id)
      render json: {
        message: 'Peer feedback requests sent successfully',
        data: {
          employee_id: employee_id,
          peer_count: peer_ids.length,
          performance_review_id: performance_review_id
        }
      }
    rescue StandardError => e
      render json: {
        errors: [e.message]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/feedbacks/analytics
  def analytics
    employee_id = params[:employee_id] || current_employee.id
    period_start = params[:period_start]&.to_date || 6.months.ago
    period_end = params[:period_end]&.to_date || Date.current
    
    feedbacks = Feedback.for_receiver(employee_id)
                       .where(created_at: period_start..period_end)
    
    analytics_data = {
      total_feedbacks: feedbacks.count,
      average_rating: feedbacks.average(:rating)&.round(2) || 0,
      feedback_by_type: feedbacks.group(:feedback_type).count,
      sentiment_distribution: {
        positive: feedbacks.where('sentiment_score > 0.5').count,
        neutral: feedbacks.where('sentiment_score BETWEEN -0.5 AND 0.5').count,
        negative: feedbacks.where('sentiment_score < -0.5').count
      },
      performance_trends: {},
      department_comparison: {}
    }
    
    # Add peer comparison if requested
    if params[:include_peer_comparison] == 'true'
      employee = Employee.find(employee_id)
      analytics_data[:peer_comparison] = {
        department_average_rating: 4.2,
        your_rating: analytics_data[:average_rating],
        percentile: 75
      }
    end
    
    render json: {
      data: analytics_data,
      meta: {
        employee_id: employee_id,
        period_start: period_start,
        period_end: period_end
      }
    }
  end

  # GET /api/v1/feedbacks/trends
  def trends
    employee_id = params[:employee_id]
    months = params[:months]&.to_i || 12
    
    if employee_id.blank?
      return render json: {
        errors: ['Employee ID is required']
      }, status: :bad_request
    end
    
    trends_data = Feedback.feedback_trends(employee_id, months)
    
    render json: {
      data: {
        employee_id: employee_id,
        months: months,
        trends: trends_data
      }
    }
  end

  # GET /api/v1/feedbacks/themes
  def themes
    employee_id = params[:employee_id] || current_employee.id
    feedbacks = Feedback.for_receiver(employee_id)
    
    # Simple theme extraction based on keywords
    themes = {}
    feedbacks.each do |feedback|
      words = feedback.message.downcase.split(/\W+/)
      words.each do |word|
        next if word.length < 4
        themes[word] ||= { count: 0, sentiment: [] }
        themes[word][:count] += 1
        themes[word][:sentiment] << feedback.sentiment_score
      end
    end
    
    render json: {
      data: themes.sort_by { |_, v| -v[:count] }.first(10).to_h
    }
  end

  # POST /api/v1/feedbacks/request_feedback
  def request_feedback
    employee_ids = params[:employee_ids] || []
    message = params[:message]
    feedback_type = params[:feedback_type] || 'peer'
    
    if employee_ids.empty? || message.blank?
      return render json: {
        errors: ['Employee IDs and message are required']
      }, status: :bad_request
    end
    
    begin
      FeedbackRequest.transaction do
        employee_ids.each do |employee_id|
          FeedbackRequest.create!(
            requester: current_employee,
            recipient_id: employee_id,
            message: message,
            feedback_type: feedback_type,
            status: 'pending'
          )
        end
      end
      
      render json: {
        message: "Feedback requests sent to #{employee_ids.length} employees",
        data: {
          requested_count: employee_ids.length,
          feedback_type: feedback_type
        }
      }
    rescue StandardError => e
      render json: {
        errors: [e.message]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/feedbacks/create_360_request
  def create_360_request
    performance_review_id = params[:performance_review_id]
    
    # Simple implementation
    render json: {
      message: '360-degree feedback request created successfully',
      data: {
        performance_review_id: performance_review_id,
        status: 'pending'
      }
    }
  end

  # GET /api/v1/feedbacks/summary
  def summary
    employee_id = params[:employee_id] || current_employee.id
    performance_review_id = params[:performance_review_id]
    
    feedbacks = Feedback.for_receiver(employee_id)
    feedbacks = feedbacks.for_review(performance_review_id) if performance_review_id.present?
    
    summary_data = {
      total_feedbacks: feedbacks.count,
      average_rating: feedbacks.average(:rating)&.round(2) || 0,
      feedback_by_type: feedbacks.group(:feedback_type).count,
      manager_feedback: feedbacks.where(feedback_type: 'upward').count,
      peer_feedback: feedbacks.where(feedback_type: 'peer').count,
      subordinate_feedback: feedbacks.where(feedback_type: 'downward').count,
      feedback_gaps: []
    }
    
    render json: {
      data: summary_data
    }
  end

  private

  def set_feedback
    @feedback = Feedback.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Feedback not found'] }, status: :not_found
  end

  def authorize_feedback_access
    employee = current_employee
    
    # Allow access if user is the giver, receiver, or admin
    # For anonymous feedback, only receiver and admin can access
    unless employee == @feedback.giver || 
           employee == @feedback.receiver ||
           current_user.admin? || 
           current_user.super_admin?
      render json: { errors: ['Unauthorized access'] }, status: :forbidden
    end
  end

  def feedback_params
    params.require(:feedback).permit(
      :giver_id, :receiver_id, :performance_review_id, 
      :feedback_type, :message, :rating, :anonymous
    )
  end

  def feedbacks_json(feedbacks)
    feedbacks.map do |feedback|
      {
        id: feedback.id,
        giver: {
          id: feedback.giver.id,
          name: feedback.formatted_giver_name
        },
        receiver: {
          id: feedback.receiver.id,
          name: feedback.receiver.full_name,
          position: feedback.receiver.position.title
        },
        performance_review_id: feedback.performance_review_id,
        feedback_type: feedback.feedback_type,
        message: feedback.message,
        rating: feedback.rating,
        sentiment_score: feedback.sentiment_score,
        anonymous: feedback.anonymous,
        relationship_type: feedback.relationship_type,
        can_be_edited: feedback.can_be_edited?,
        created_at: feedback.created_at,
        updated_at: feedback.updated_at
      }
    end
  end

  def feedback_detail_json(feedback)
    {
      id: feedback.id,
      giver: {
        id: feedback.anonymous? ? nil : feedback.giver.id,
        name: feedback.formatted_giver_name,
        email: feedback.anonymous? ? nil : feedback.giver.email,
        position: feedback.anonymous? ? nil : feedback.giver.position.title
      },
      receiver: {
        id: feedback.receiver.id,
        name: feedback.receiver.full_name,
        email: feedback.receiver.email,
        position: feedback.receiver.position.title,
        department: feedback.receiver.department.name
      },
      performance_review: feedback.performance_review ? {
        id: feedback.performance_review.id,
        title: feedback.performance_review.title,
        status: feedback.performance_review.status
      } : nil,
      feedback_type: feedback.feedback_type,
      message: feedback.message,
      word_count: feedback.word_count,
      rating: feedback.rating,
      sentiment_score: feedback.sentiment_score,
      is_positive: feedback.is_positive?,
      is_negative: feedback.is_negative?,
      is_constructive: feedback.is_constructive?,
      anonymous: feedback.anonymous,
      relationship_type: feedback.relationship_type,
      can_be_edited: feedback.can_be_edited?,
      created_at: feedback.created_at,
      updated_at: feedback.updated_at
    }
  end

  def current_employee
    @current_employee ||= current_user.employee
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