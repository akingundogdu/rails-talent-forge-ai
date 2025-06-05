module Api
  module V1
    class DepartmentsController < BaseController
      before_action :set_department, only: [:show, :update, :destroy, :org_chart]

      # GET /api/v1/departments
      def index
        @departments = policy_scope(Department)
        @departments = paginate(@departments)
        render json: @departments
      end

      # GET /api/v1/departments/:id
      def show
        authorize @department
        render json: @department
      end

      # POST /api/v1/departments
      def create
        @department = Department.new(department_params)
        authorize @department

        if @department.save
          render json: @department, status: :created
        else
          render json: { errors: @department.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/departments/:id
      def update
        authorize @department

        if @department.update(department_params)
          render json: @department
        else
          render json: { errors: @department.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/departments/:id
      def destroy
        authorize @department
        @department.destroy
        head :no_content
      end

      # GET /api/v1/departments/:id/org_chart
      def org_chart
        authorize @department
        render json: Department.cached_org_chart(@department.id)
      end

      # GET /api/v1/departments/tree
      def tree
        authorize Department
        render json: Department.cached_tree
      end

      def bulk_create
        authorize Department
        result = BulkOperationService.bulk_create(Department, bulk_params, bulk_operation_options)
        
        if result[:errors].empty?
          render json: result[:success], status: :created
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      def bulk_update
        authorize Department
        result = BulkOperationService.bulk_update(Department, bulk_params, bulk_operation_options)
        
        if result[:errors].empty?
          render json: result[:success]
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      def bulk_delete
        authorize Department
        result = BulkOperationService.bulk_delete(Department, params[:ids], bulk_operation_options)
        
        if result[:errors].empty?
          head :no_content
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      private

      def set_department
        @department = Department.cached_find(params[:id])
      end

      def department_params
        params.require(:department).permit(:name, :description, :parent_department_id, :manager_id)
      end

      def bulk_params
        params.require(:departments)
      end

      def bulk_operation_options
        {
          batch_size: params[:batch_size] || 100,
          validate_all: params[:validate_all] != 'false'
        }
      end
    end
  end
end 