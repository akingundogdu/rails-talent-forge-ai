module AuthHelpers
  def auth_headers(user)
    token = JsonWebToken.encode(user_id: user.id)
    { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
  end

  def json_response
    JSON.parse(response.body)
  end

  # For controller tests - override Devise's sign_in to use JWT
  def sign_in(user)
    if defined?(request) && request
      token = JsonWebToken.encode(user_id: user.id)
      request.headers['Authorization'] = "Bearer #{token}"
      
      # Mock the warden authentication for controller tests
      warden = double('warden')
      allow(warden).to receive(:authenticate).with(:jwt).and_return(user)
      allow(warden).to receive(:authenticate!).and_return(user)
      allow(request).to receive(:env).and_return({ 'warden' => warden })
      
      # Ensure current_user returns the correct user
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    else
      super(user) if defined?(super)
    end
  end

  # For request tests with specific user
  def sign_in_user(user)
    token = JsonWebToken.encode(user_id: user.id)
    @auth_headers = { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
  end

  # Helper to get auth headers for requests
  def auth_headers_for(user)
    token = JsonWebToken.encode(user_id: user.id)
    { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
  end

  # Helper to sign in as a specific employee (for controller tests)
  def sign_in_as_employee(employee)
    user = employee.user
    sign_in(user)
    allow(controller).to receive(:current_employee).and_return(employee) if defined?(controller)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :controller
end 