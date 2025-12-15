# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /matches/new", type: :request do
  describe "new" do
    it "returns http success" do
      get new_match_path
      expect(response).to have_http_status(:success)
    end
  end
end
