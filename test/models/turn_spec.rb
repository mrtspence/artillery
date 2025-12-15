# frozen_string_literal: true

require "test_helper"

RSpec.describe Turn, type: :model do
  describe "associations" do
    let(:match) { create(:match) }
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }
    let(:match_player) { match.add_player!(player, loadout) }

    subject do
      create(:turn,
        match: match,
        match_player: match_player,
        turn_number: 0,
        input_data: {},
        result_data: {}
      )
    end

    it { is_expected.to belong_to(:match) }
    it { is_expected.to belong_to(:match_player) }
  end

  describe "validations" do
    let(:match) { create(:match) }
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }
    let(:match_player) { match.add_player!(player, loadout) }

    subject do
      create(:turn,
        match: match,
        match_player: match_player,
        turn_number: 0,
        input_data: {},
        result_data: {}
      )
    end

    it { is_expected.to validate_presence_of(:turn_number) }
    it { is_expected.to validate_numericality_of(:turn_number).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:points_earned) }
    it { is_expected.to validate_numericality_of(:points_earned).is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    let(:match) { create(:match) }
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }
    let(:match_player) { match.add_player!(player, loadout) }

    let!(:turn1) do
      create(:turn,
        match: match,
        match_player: match_player,
        turn_number: 0,
        input_data: {},
        result_data: {}
      )
    end

    let!(:turn2) do
      create(:turn,
        match: match,
        match_player: match_player,
        turn_number: 1,
        input_data: {},
        result_data: {}
      )
    end

    describe ".by_turn_number" do
      it "returns turns ordered by turn_number" do
        expect(Turn.by_turn_number).to eq([turn1, turn2])
      end
    end
  end

  describe "delegations" do
    let(:match) { create(:match) }
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }
    let(:match_player) { match.add_player!(player, loadout) }

    let(:turn) do
      create(:turn,
        match: match,
        match_player: match_player,
        turn_number: 0,
        input_data: {},
        result_data: {}
      )
    end

    it "delegates player to match_player" do
      expect(turn.player).to eq(player)
    end
  end
end
