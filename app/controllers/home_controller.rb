class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    render json: { message: "Welcome to the API" }
  end
end
