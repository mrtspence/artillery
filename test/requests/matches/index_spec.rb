# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /matches", type: :request do
  describe "index" do
    let!(:active_match) { create(:match, status: 'setup') }
    let!(:in_progress_match) { create(:match, status: 'in_progress') }
    let!(:completed_match) { create(:match, status: 'completed') }

    it "returns http success" do
      get matches_path
      expect(response).to have_http_status(:success)
    end

    it "displays active matches" do
      get matches_path
      expect(response.body).to include(active_match.lobby_code)
      expect(response.body).to include(in_progress_match.lobby_code)
    end

    it "does not display completed matches" do
      get matches_path
      expect(response.body).not_to include(completed_match.lobby_code)
    end
  end
end
