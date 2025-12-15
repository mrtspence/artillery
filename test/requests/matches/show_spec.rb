# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GET /matches/:id", type: :request do
  describe "show" do
    let(:match) { create(:match) }
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }
    let!(:match_player) { match.add_player!(player, loadout) }

    it "returns http success" do
      get match_path(match)
      expect(response).to have_http_status(:success)
    end

    it "displays match information" do
      get match_path(match)
      expect(response.body).to include(match.lobby_code)
      expect(response.body).to include(player.username)
    end
  end
end
