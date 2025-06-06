module DeviseHelper
  def sign_in(user)
    warden = request.env['warden']
    allow(warden).to receive(:authenticate!).and_return(user)
    allow(warden).to receive(:authenticate).with(:jwt).and_return(user)
    allow(controller).to receive(:current_user).and_return(user)
  end
end

RSpec.configure do |config|
  config.include DeviseHelper, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :controller
end 