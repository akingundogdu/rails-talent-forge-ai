# JWT Strategy for Devise
Warden::Strategies.add(:jwt) do
  def valid?
    request.headers['Authorization'].present?
  end

  def authenticate!
    token = request.headers['Authorization']&.split(' ')&.last
    return fail!('Missing token') unless token

    decoded_token = JsonWebToken.decode(token)
    return fail!('Invalid token') unless decoded_token

    user = User.find_by(id: decoded_token[:user_id])
    return fail!('User not found') unless user

    success!(user)
  rescue StandardError => e
    fail!("Authentication failed: #{e.message}")
  end
end

# Configure Devise to use JWT strategy
Devise.setup do |config|
  config.warden do |manager|
    manager.default_strategies(scope: :user).unshift :jwt
  end
end 