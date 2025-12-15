# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /match_joins", type: :request do
  describe "create" do
    let(:match) { create(:match) }
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }

    context "with valid lobby code and player" do
      it "adds player to the match" do
        expect {
          post match_joins_path, params: {
            lobby_code: match.lobby_code,
            player_id: player.id,
            loadout_id: loadout.id
          }
        }.to change(match.match_players, :count).by(1)
      end

      it "redirects to the match" do
        post match_joins_path, params: {
          lobby_code: match.lobby_code,
          player_id: player.id,
          loadout_id: loadout.id
        }
        expect(response).to redirect_to(match_path(match))
      end

      it "sets a success notice" do
        post match_joins_path, params: {
          lobby_code: match.lobby_code,
          player_id: player.id,
          loadout_id: loadout.id
        }
        expect(flash[:notice]).to eq("Joined match!")
      end
    end

    context "with invalid lobby code" do
      it "does not add player to any match" do
        expect {
          post match_joins_path, params: {
            lobby_code: "INVALID",
            player_id: player.id,
            loadout_id: loadout.id
          }
        }.not_to change(MatchPlayer, :count)
      end

      it "redirects to matches index" do
        post match_joins_path, params: {
          lobby_code: "INVALID",
          player_id: player.id,
          loadout_id: loadout.id
        }
        expect(response).to redirect_to(matches_path)
      end

      it "sets an error alert" do
        post match_joins_path, params: {
          lobby_code: "INVALID",
          player_id: player.id,
          loadout_id: loadout.id
        }
        expect(flash[:alert]).to include("not found")
      end
    end

    context "when player already in match" do
      before do
        match.add_player!(player, loadout)
      end

      it "does not add player again" do
        expect {
          post match_joins_path, params: {
            lobby_code: match.lobby_code,
            player_id: player.id,
            loadout_id: loadout.id
          }
        }.not_to change(match.match_players, :count)
      end

      it "sets an error alert" do
        post match_joins_path, params: {
          lobby_code: match.lobby_code,
          player_id: player.id,
          loadout_id: loadout.id
        }
        expect(flash[:alert]).to include("already in match")
      end
    end

    context "when match is full" do
      before do
        Match::MAX_PLAYERS.times do |i|
          p = create(:player, username: "full_match_player_#{i}")
          l = create(:player_loadout, player: p)
          match.add_player!(p, l)
        end
      end

      it "does not add player" do
        expect {
          post match_joins_path, params: {
            lobby_code: match.lobby_code,
            player_id: player.id,
            loadout_id: loadout.id
          }
        }.not_to change(match.match_players, :count)
      end

      it "sets an error alert" do
        post match_joins_path, params: {
          lobby_code: match.lobby_code,
          player_id: player.id,
          loadout_id: loadout.id
        }
        expect(flash[:alert]).to include("full")
      end
    end

    context "when match not in setup phase" do
      let(:match) { create(:match, status: 'in_progress') }

      it "does not add player" do
        expect {
          post match_joins_path, params: {
            lobby_code: match.lobby_code,
            player_id: player.id,
            loadout_id: loadout.id
          }
        }.not_to change(match.match_players, :count)
      end

      it "sets an error alert" do
        post match_joins_path, params: {
          lobby_code: match.lobby_code,
          player_id: player.id,
          loadout_id: loadout.id
        }
        expect(flash[:alert]).to include("not in setup phase")
      end
    end
  end
end
