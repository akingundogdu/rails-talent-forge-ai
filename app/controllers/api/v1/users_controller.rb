module Api
  module V1
    class UsersController < BaseController
      skip_before_action :authenticate_user!, only: [:create]
      skip_after_action :verify_authorized, only: [:create]

      def create
        @user = User.new(user_params)
        if @user.save
          render json: @user, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        @user = User.find(params[:id])
        authorize @user
        render json: @user
      end

      def update
        @user = User.find(params[:id])
        authorize @user
        if @user.update(user_params)
          render json: @user
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end
    end
  end
end 