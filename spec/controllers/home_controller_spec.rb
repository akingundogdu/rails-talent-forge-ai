require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
    end

    it "returns welcome message" do
      get :index
      expect(JSON.parse(response.body)['message']).to eq("Welcome to the API")
    end
  end
end 