require "test_helper"

module Api
  module V1
    class EmployeesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @employee = employees(:john)
        @manager = employees(:jane)
        @position = positions(:senior_engineer)
        @department = departments(:engineering)
      end

      test "should get index" do
        get api_v1_employees_url
        assert_response :success
        assert_not_empty json_response
      end

      test "should create employee" do
        assert_difference("Employee.count") do
          post api_v1_employees_url, params: {
            employee: {
              first_name: "New",
              last_name: "Employee",
              email: "new.employee@example.com",
              position_id: @position.id,
              manager_id: @manager.id
            }
          }
        end

        assert_response :created
        assert_equal "new.employee@example.com", json_response["email"]
      end

      test "should show employee" do
        get api_v1_employee_url(@employee)
        assert_response :success
        assert_equal @employee.email, json_response["email"]
      end

      test "should update employee" do
        patch api_v1_employee_url(@employee), params: {
          employee: {
            first_name: "Updated"
          }
        }
        assert_response :success
        assert_equal "Updated", json_response["first_name"]
      end

      test "should destroy employee" do
        assert_difference("Employee.count", -1) do
          delete api_v1_employee_url(@employee)
        end

        assert_response :no_content
      end

      test "should get employee subordinates" do
        get subordinates_api_v1_employee_url(@manager)
        assert_response :success
        assert_equal @manager.full_name, json_response["name"]
        assert_includes json_response.keys, "subordinates"
      end

      test "should get employees by department" do
        get api_v1_department_employees_url(@department)
        assert_response :success
        assert_not_empty json_response
        assert_equal @department.id, json_response.first["department_id"]
      end

      test "should get employees by position" do
        get api_v1_position_employees_url(@position)
        assert_response :success
        assert_not_empty json_response
        assert_equal @position.id, json_response.first["position_id"]
      end

      test "should not create employee with invalid data" do
        post api_v1_employees_url, params: {
          employee: {
            first_name: "",
            email: "invalid-email"
          }
        }
        assert_response :unprocessable_entity
        assert_includes json_response["errors"], "First name can't be blank"
        assert_includes json_response["errors"], "Email is invalid"
      end

      test "should not create employee with invalid manager position level" do
        subordinate_position = positions(:junior_engineer)
        
        post api_v1_employees_url, params: {
          employee: {
            first_name: "Test",
            last_name: "Employee",
            email: "test.employee@example.com",
            position_id: @position.id,
            manager_id: employees(:bob).id # Bob has a lower position level
          }
        }
        
        assert_response :unprocessable_entity
        assert_includes json_response["errors"], "Manager must have a higher position level"
      end

      test "should not create employee with circular management" do
        new_employee = Employee.create!(
          first_name: "Test",
          last_name: "Employee",
          email: "test.employee@example.com",
          position: @position
        )
        @employee.update(manager: new_employee)
        
        patch api_v1_employee_url(new_employee), params: {
          employee: {
            manager_id: @employee.id
          }
        }
        
        assert_response :unprocessable_entity
        assert_includes json_response["errors"], "circular management is not allowed"
      end
    end
  end
end 