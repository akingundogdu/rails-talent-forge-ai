module Api
  module V1
    class PermissionsController < BaseController
      before_action :set_user
      before_action :set_permission, only: [:show, :update, :destroy]

      def index
        authorize @user, :manage_permissions?
        @permissions = policy_scope(@user.permissions)
        @permissions = @permissions.where(resource: params[:resource]) if params[:resource].present?
        render json: @permissions
      end

      def show
        authorize @permission
        render json: @permission
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

      def update
        authorize @permission
        if @permission.update(permission_params)
          render json: @permission
        else
          render json: { errors: @permission.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @user, :manage_permissions?
        @permission.destroy
        head :no_content
      end

      def bulk_create
        authorize Permission
        result = BulkOperationService.bulk_create(Permission, bulk_create_params, batch_size: params[:batch_size])
        if result[:errors].empty?
          render json: result[:success], status: :created
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      rescue BulkOperationService::BulkOperationError => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end

      private

      def set_user
        @user = User.find(params[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      def set_permission
        @permission = @user.permissions.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Permission not found' }, status: :not_found
      end

      def permission_params
        params.require(:permission).permit(:resource, :action, :resource_id)
      end

      def bulk_create_params
        params.require(:permissions).map do |permission_params|
          permission_params.permit(:resource, :action, :resource_id).merge(user_id: params[:user_id])
        end
      end
    end
  end
end 