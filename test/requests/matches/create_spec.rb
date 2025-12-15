# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /matches", type: :request do
  describe "create" do
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }

    context "with valid parameters" do
      it "creates a new match" do
        expect {
          post matches_path, params: { player_id: player.id, loadout_id: loadout.id }
        }.to change(Match, :count).by(1)
      end

      it "adds the player as host" do
        post matches_path, params: { player_id: player.id, loadout_id: loadout.id }
        match = Match.last
        expect(match.match_players.hosts.first.player).to eq(player)
      end

      it "redirects to the match" do
        post matches_path, params: { player_id: player.id, loadout_id: loadout.id }
        expect(response).to redirect_to(match_path(Match.last))
      end

      it "sets a flash notice with lobby code" do
        post matches_path, params: { player_id: player.id, loadout_id: loadout.id }
        expect(flash[:notice]).to include("Lobby code")
      end
    end

    context "without player parameters" do
      it "creates a match without players" do
        expect {
          post matches_path
        }.to change(Match, :count).by(1)
      end

      it "redirects to the match" do
        post matches_path
        expect(response).to redirect_to(match_path(Match.last))
      end
    end
  end
end
