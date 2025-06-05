require "test_helper"

module Api
  module V1
    class DepartmentsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @department = departments(:engineering)
        @sub_department = departments(:frontend)
        @manager = employees(:john)
      end

      test "should get index" do
        get api_v1_departments_url
        assert_response :success
        assert_not_empty json_response
      end

      test "should create department" do
        assert_difference("Department.count") do
          post api_v1_departments_url, params: {
            department: {
              name: "New Department",
              description: "Test department",
              parent_department_id: @department.id,
              manager_id: @manager.id
            }
          }
        end

        assert_response :created
        assert_equal "New Department", json_response["name"]
      end

      test "should show department" do
        get api_v1_departments_url(@department)
        assert_response :success
        assert_equal @department.name, json_response["name"]
      end

      test "should update department" do
        patch api_v1_departments_url(@department), params: {
          department: {
            name: "Updated Department"
          }
        }
        assert_response :success
        assert_equal "Updated Department", json_response["name"]
      end

      test "should destroy department" do
        assert_difference("Department.count", -1) do
          delete api_v1_departments_url(@department)
        end

        assert_response :no_content
      end

      test "should get department tree" do
        get tree_api_v1_departments_url
        assert_response :success
        assert_not_empty json_response
        assert_nil json_response.first["parent_department_id"]
      end

      test "should get department org chart" do
        get org_chart_api_v1_department_url(@department)
        assert_response :success
        assert_equal @department.name, json_response["name"]
        assert_includes json_response.keys, "children"
        assert_includes json_response.keys, "positions"
      end

      test "should not create department with invalid data" do
        post api_v1_departments_url, params: {
          department: {
            name: ""
          }
        }
        assert_response :unprocessable_entity
        assert_includes json_response["errors"], "Name can't be blank"
      end

      test "should not create department with circular hierarchy" do
        post api_v1_departments_url, params: {
          department: {
            name: "Test Department",
            parent_department_id: @sub_department.id
          }
        }
        @department.update(parent_department_id: Department.last.id)
        
        assert_response :unprocessable_entity
        assert_includes json_response["errors"], "circular hierarchy is not allowed"
      end
    end
  end
end 