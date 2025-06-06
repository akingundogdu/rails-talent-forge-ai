module Api
  module V1
    class BaseController < ApplicationController
      include Pundit::Authorization
      include UserActivity

      before_action :authenticate_user!
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request
      rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
      rescue_from StandardError, with: :internal_server_error

      private

      def not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
      end

      def bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end

      def user_not_authorized(exception = nil)
        render json: { error: 'You are not authorized to perform this action.' }, status: :forbidden
      end

      def internal_server_error(exception)
        render json: { error: exception.message }, status: :internal_server_error
      end

      def paginate(collection)
        collection.page(params[:page] || 1).per(params[:per_page] || 25)
      end
    end
  end
end 