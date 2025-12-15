# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /matches/:match_id/start", type: :request do
  describe "create" do
    let(:match) { create(:match) }
    let(:player1) { create(:player, username: "player_1") }
    let(:player2) { create(:player, username: "player_2") }
    let(:loadout1) { create(:player_loadout, player: player1) }
    let(:loadout2) { create(:player_loadout, player: player2) }

    context "with enough players" do
      before do
        match.add_player!(player1, loadout1)
        match.add_player!(player2, loadout2)
      end

      it "starts the match" do
        post match_start_path(match)
        expect(match.reload.status).to eq('in_progress')
      end

      it "sets the current player" do
        post match_start_path(match)
        expect(match.reload.current_player).to eq(player1)
      end

      it "redirects to the match" do
        post match_start_path(match)
        expect(response).to redirect_to(match_path(match))
      end

      it "sets a success notice" do
        post match_start_path(match)
        expect(flash[:notice]).to eq("Match started!")
      end
    end

    context "without enough players" do
      before do
        match.add_player!(player1, loadout1)
      end

      it "does not start the match" do
        post match_start_path(match)
        expect(match.reload.status).to eq('setup')
      end

      it "redirects back to the match" do
        post match_start_path(match)
        expect(response).to redirect_to(match_path(match))
      end

      it "sets an error alert" do
        post match_start_path(match)
        expect(flash[:alert]).to include("Need at least")
      end
    end

    context "when match already started" do
      before do
        match.add_player!(player1, loadout1)
        match.add_player!(player2, loadout2)
        match.start!
      end

      it "does not change the match status" do
        post match_start_path(match)
        expect(match.reload.status).to eq('in_progress')
      end

      it "sets an error alert" do
        post match_start_path(match)
        expect(flash[:alert]).to include("already started")
      end
    end
  end
end
