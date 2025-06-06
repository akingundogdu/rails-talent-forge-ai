module Api
  module V1
    class UsersController < BaseController
      skip_before_action :authenticate_user!, only: [:create, :sign_in, :sign_up]
      skip_after_action :verify_authorized, only: [:create, :sign_in, :sign_up]
      skip_after_action :verify_policy_scoped, except: [:index]

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

      def sign_in
        user = User.find_by(email: params[:email])
        if user&.valid_password?(params[:password])
          token = JsonWebToken.encode(user_id: user.id)
          render json: { token: token }
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end

      def sign_up
        user = User.new(sign_up_params)
        if user.save
          token = JsonWebToken.encode(user_id: user.id)
          render json: { token: token }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def sign_out
        authorize current_user, :sign_out?
        current_user.update(jti: SecureRandom.uuid)
        head :no_content
      end

      def profile
        authorize current_user, :profile?
        render json: current_user
      end

      def update_profile
        authorize current_user, :update_profile?
        if current_user.update(update_profile_params)
          render json: current_user
        else
          render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def change_password
        authorize current_user, :change_password?
        if current_user.valid_password?(params[:current_password])
          if current_user.update(password_params)
            render json: { message: 'Password updated successfully' }
          else
            render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { error: 'Current password is incorrect' }, status: :unauthorized
        end
      end

      private

      def user_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation)
      end

      def update_profile_params
        params.require(:user).permit(:email)
      end

      def password_params
        params.permit(:password, :password_confirmation)
      end
    end
  end
end 