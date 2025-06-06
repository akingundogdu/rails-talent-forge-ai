module ControllerHelpers
  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :controller
end 