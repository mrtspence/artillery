# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /matches/:match_id/turns", type: :request do
  describe "create" do
    let(:match) { create(:match) }
    let(:player1) { create(:player, username: "player_1") }
    let(:player2) { create(:player, username: "player_2") }
    let(:loadout1) { create(:player_loadout, player: player1) }
    let(:loadout2) { create(:player_loadout, player: player2) }

    context "with valid turn data" do
      let(:turn_params) do
        {
          player_id: player1.id,
          turn: {
            input_data: { elevation: 45, deflection: 0 },
            result_data: { points: 100 }
          }
        }
      end

      before do
        match.add_player!(player1, loadout1)
        match.add_player!(player2, loadout2)
        match.start!
      end

      it "creates a new turn" do
        expect {
          post match_turns_path(match), params: turn_params
        }.to change(Turn, :count).by(1)
      end

      it "advances to next player" do
        post match_turns_path(match), params: turn_params
        expect(match.reload.current_player).to eq(player2)
      end

      it "redirects to the match" do
        post match_turns_path(match), params: turn_params
        expect(response).to redirect_to(match_path(match))
      end

      it "sets a success notice" do
        post match_turns_path(match), params: turn_params
        expect(flash[:notice]).to eq("Turn submitted!")
      end
    end

    context "when not the current player's turn" do
      let(:turn_params) do
        {
          player_id: player2.id,
          turn: {
            input_data: {},
            result_data: { points: 0 }
          }
        }
      end

      before do
        match.add_player!(player1, loadout1)
        match.add_player!(player2, loadout2)
        match.start!
      end

      it "does not create a turn" do
        expect {
          post match_turns_path(match), params: turn_params
        }.not_to change(Turn, :count)
      end

      it "sets an error alert" do
        post match_turns_path(match), params: turn_params
        expect(flash[:alert]).to include("Not this player's turn")
      end
    end

    context "when match is not in progress" do
      let(:match) { create(:match, status: 'setup') }
      let(:turn_params) do
        {
          player_id: player1.id,
          turn: {
            input_data: {},
            result_data: { points: 0 }
          }
        }
      end

      before do
        # Add players but don't start the match
        match.add_player!(player1, loadout1)
        match.add_player!(player2, loadout2)
        # Note: NOT calling match.start! here
      end

      it "does not create a turn" do
        expect {
          post match_turns_path(match), params: turn_params
        }.not_to change(Turn, :count)
      end

      it "sets an error alert" do
        post match_turns_path(match), params: turn_params
        expect(flash[:alert]).to include("not in progress")
      end
    end
  end
end
