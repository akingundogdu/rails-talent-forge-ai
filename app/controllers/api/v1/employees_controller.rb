module Api
  module V1
    class EmployeesController < BaseController
      before_action :set_employee, only: [:show, :update, :destroy, :subordinates]

      # GET /api/v1/employees
      def index
        @employees = policy_scope(Employee)
        @employees = paginate(@employees)
        render json: @employees
      end

      # GET /api/v1/employees/:id
      def show
        authorize @employee
        render json: @employee
      end

      # POST /api/v1/employees
      def create
        @employee = Employee.new(employee_params)
        authorize @employee

        if @employee.save
          render json: @employee, status: :created
        else
          render json: { errors: @employee.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/employees/:id
      def update
        authorize @employee

        if @employee.update(employee_params)
          render json: @employee
        else
          render json: { errors: @employee.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/employees/:id
      def destroy
        authorize @employee
        @employee.destroy
        head :no_content
      end

      # GET /api/v1/employees/:id/subordinates
      def subordinates
        authorize @employee
        render json: @employee.subordinates_tree
      end

      # GET /api/v1/departments/:department_id/employees
      def by_department
        @department = Department.find(params[:department_id])
        @employees = policy_scope(@department.employees)
        @employees = paginate(@employees)
        render json: @employees
      end

      # GET /api/v1/positions/:position_id/employees
      def by_position
        @position = Position.find(params[:position_id])
        @employees = policy_scope(@position.employees)
        @employees = paginate(@employees)
        render json: @employees
      end

      def bulk_create
        authorize Employee
        result = BulkOperationService.bulk_create(Employee, bulk_params, bulk_operation_options)
        
        if result[:errors].empty?
          render json: result[:success], status: :created
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      def bulk_update
        authorize Employee
        result = BulkOperationService.bulk_update(Employee, bulk_params, bulk_operation_options)
        
        if result[:errors].empty?
          render json: result[:success]
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      def bulk_delete
        authorize Employee
        result = BulkOperationService.bulk_delete(Employee, params[:ids], bulk_operation_options)
        
        if result[:errors].empty?
          head :no_content
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      private

      def set_employee
        @employee = Employee.cached_find(params[:id])
      end

      def employee_params
        params.require(:employee).permit(
          :first_name, :last_name, :email,
          :position_id, :manager_id, :user_id
        )
      end

      def bulk_params
        params.require(:employees)
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