class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  include Pundit::Authorization

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

  private

  def authenticate_user!
    unless current_user
      render json: { error: 'You need to sign in or sign up before continuing.' }, status: :unauthorized
    end
  end

  def current_user
    @current_user ||= warden.authenticate(:jwt)
  end

  def user_not_authorized
    render json: { error: 'You are not authorized to perform this action.' }, status: :forbidden
  end

  def not_found
    render json: { error: 'Record not found' }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def warden
    request.env['warden']
  end
end
