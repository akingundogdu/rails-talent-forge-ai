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
    else
      super(user) if defined?(super)
    end
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :controller
end 