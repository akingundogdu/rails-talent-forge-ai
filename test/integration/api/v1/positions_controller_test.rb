require "test_helper"

module Api
  module V1
    class PositionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @position = positions(:senior_engineer)
        @department = departments(:engineering)
        @parent_position = positions(:lead_engineer)
      end

      test "should get index" do
        get api_v1_positions_url
        assert_response :success
        assert_not_empty json_response
      end

      test "should create position" do
        assert_difference("Position.count") do
          post api_v1_positions_url, params: {
            position: {
              title: "New Position",
              description: "Test position",
              level: 3,
              department_id: @department.id,
              parent_position_id: @parent_position.id
            }
          }
        end

        assert_response :created
        assert_equal "New Position", json_response["title"]
      end

      test "should show position" do
        get api_v1_position_url(@position)
        assert_response :success
        assert_equal @position.title, json_response["title"]
      end

      test "should update position" do
        patch api_v1_position_url(@position), params: {
          position: {
            title: "Updated Position"
          }
        }
        assert_response :success
        assert_equal "Updated Position", json_response["title"]
      end

      test "should destroy position" do
        assert_difference("Position.count", -1) do
          delete api_v1_position_url(@position)
        end

        assert_response :no_content
      end

      test "should get position hierarchy" do
        get hierarchy_api_v1_position_url(@parent_position)
        assert_response :success
        assert_equal @parent_position.title, json_response["title"]
        assert_includes json_response.keys, "subordinate_positions"
      end

      test "should get positions by department" do
        get api_v1_department_positions_url(@department)
        assert_response :success
        assert_not_empty json_response
        assert_equal @department.id, json_response.first["department_id"]
      end

      test "should not create position with invalid data" do
        post api_v1_positions_url, params: {
          position: {
            title: "",
            level: 0
          }
        }
        assert_response :unprocessable_entity
        assert_includes json_response["errors"], "Title can't be blank"
        assert_includes json_response["errors"], "Level must be greater than 0"
      end

      test "should not create position with invalid hierarchy level" do
        post api_v1_positions_url, params: {
          position: {
            title: "Test Position",
            level: @parent_position.level + 1,
            department_id: @department.id,
            parent_position_id: @parent_position.id
          }
        }
        assert_response :unprocessable_entity
        assert_includes json_response["errors"], "Level must be lower than parent position's level"
      end

      test "should not create position with circular hierarchy" do
        new_position = Position.create!(
          title: "Test Position",
          level: 2,
          department: @department
        )
        @position.update(parent_position: new_position)
        
        patch api_v1_position_url(new_position), params: {
          position: {
            parent_position_id: @position.id
          }
        }
        
        assert_response :unprocessable_entity
        assert_includes json_response["errors"], "circular hierarchy is not allowed"
      end
    end
  end
end 