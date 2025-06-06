module Api
  module V1
    class EmployeesController < BaseController
      before_action :set_employee, only: [:show, :update, :destroy, :subordinates, :manager]

      # GET /api/v1/employees
      def index
        @employees = policy_scope(Employee)
        @employees = @employees.where('first_name ILIKE ? OR last_name ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
        @employees = @employees.page(params[:page]).per(params[:per_page])
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
        @subordinates = @employee.subordinates
        render json: @subordinates
      end

      # GET /api/v1/employees/:id/manager
      def manager
        authorize @employee
        @manager = @employee.manager
        render json: @manager
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

      def search
        @employees = policy_scope(Employee).where('first_name ILIKE ? OR last_name ILIKE ?', "%#{params[:query]}%", "%#{params[:query]}%")
        authorize Employee, :search?
        render json: @employees
      end

      def bulk_create
        authorize Employee
        result = BulkOperationService.bulk_create(Employee, bulk_create_params, batch_size: params[:batch_size])
        if result[:errors].empty?
          render json: result[:success], status: :created
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      rescue BulkOperationService::BulkOperationError => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
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
        @employee = Employee.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Employee not found' }, status: :not_found
      end

      def employee_params
        params.require(:employee).permit(
          :first_name, :last_name, :email,
          :position_id, :manager_id, :user_id
        )
      end

      def bulk_create_params
        params.require(:employees).map do |employee_params|
          employee_params.permit(:first_name, :last_name, :email, :position_id, :user_id)
        end
      end

      def bulk_params
        params.require(:employees).map do |emp_params|
          emp_params.permit(:first_name, :last_name, :email, :position_id, :user_id, :manager_id)
        end
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