module Api
  module V1
    class PermissionsController < BaseController
      before_action :set_user
      before_action :set_permission, only: [:destroy]

      def index
        authorize @user, :manage_permissions?
        @permissions = @user.permissions
        render json: @permissions
      end

      def create
        authorize @user, :manage_permissions?
        @permission = @user.permissions.build(permission_params)
        
        if @permission.save
          render json: @permission, status: :created
        else
          render json: { errors: @permission.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @user, :manage_permissions?
        @permission.destroy
        head :no_content
      end

      private

      def set_user
        @user = User.find(params[:user_id])
      end

      def set_permission
        @permission = @user.permissions.find(params[:id])
      end

      def permission_params
        params.require(:permission).permit(:resource, :action, :resource_id)
      end
    end
  end
end 