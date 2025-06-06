module Api
  module V1
    class PositionsController < BaseController
      before_action :set_position, only: [:show, :update, :destroy, :hierarchy, :employees]

      # GET /api/v1/positions
      def index
        @positions = policy_scope(Position)
        @positions = @positions.where(department_id: params[:department_id]) if params[:department_id].present?
        @positions = @positions.page(params[:page]).per(params[:per_page])
        render json: @positions
      end

      # GET /api/v1/positions/:id
      def show
        authorize @position
        render json: @position, include: [:department, :parent_position, :subordinate_positions, :employees]
      end

      # POST /api/v1/positions
      def create
        @position = Position.new(position_params)
        authorize @position

        if @position.save
          render json: @position, status: :created
        else
          render json: { errors: @position.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/positions/:id
      def update
        authorize @position

        if @position.update(position_params)
          render json: @position
        else
          render json: { errors: @position.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/positions/:id
      def destroy
        authorize @position
        @position.destroy
        head :no_content
      end

      # GET /api/v1/positions/:id/hierarchy
      def hierarchy
        authorize @position
        render json: @position.hierarchy
      end

      # GET /api/v1/departments/:department_id/positions
      def by_department
        @department = Department.find(params[:department_id])
        @positions = policy_scope(@department.positions)
        @positions = paginate(@positions)
        render json: @positions, include: :parent_position
      end

      def tree
        @positions = policy_scope(Position.roots)
        authorize Position, :tree?
        render json: @positions.map(&:to_node)
      end

      def employees
        authorize @position, :employees?
        @employees = policy_scope(@position.employees)
        render json: @employees
      end

      def bulk_create
        authorize Position
        result = BulkOperationService.bulk_create(Position, bulk_create_params, batch_size: params[:batch_size])
        if result.success?
          render json: result.records, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def bulk_update
        authorize Position
        result = BulkOperationService.bulk_update(Position, bulk_params, bulk_operation_options)
        
        if result[:errors].empty?
          render json: result[:success]
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      def bulk_delete
        authorize Position
        result = BulkOperationService.bulk_delete(Position, params[:ids], bulk_operation_options)
        
        if result[:errors].empty?
          head :no_content
        else
          render json: { errors: result[:errors] }, status: :unprocessable_entity
        end
      end

      private

      def set_position
        @position = Position.cached_find(params[:id])
      end

      def position_params
        params.require(:position).permit(:title, :description, :level, :department_id, :parent_position_id)
      end

      def bulk_create_params
        params.require(:positions).map do |position_params|
          position_params.permit(:title, :description, :level, :department_id, :parent_position_id)
        end
      end

      def bulk_params
        params.require(:positions)
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