# frozen_string_literal: true

require "test_helper"

RSpec.describe MatchState, type: :model do
  describe "associations" do
    subject { create(:match).match_state }

    it { is_expected.to belong_to(:match) }
  end

  describe "validations" do
    subject { create(:match).match_state }

    it { is_expected.to validate_presence_of(:current_turn_number) }
    it { is_expected.to validate_numericality_of(:current_turn_number).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:turn_limit) }
    it { is_expected.to validate_numericality_of(:turn_limit).is_greater_than(0) }
  end

  describe "#turns_remaining" do
    let(:match_state) { create(:match).match_state }

    it "calculates remaining turns" do
      match_state.update!(current_turn_number: 3, turn_limit: 10)
      expect(match_state.turns_remaining).to eq(7)
    end

    it "returns 0 when at turn limit" do
      match_state.update!(current_turn_number: 10, turn_limit: 10)
      expect(match_state.turns_remaining).to eq(0)
    end
  end

  describe "#game_over?" do
    let(:match_state) { create(:match).match_state }

    it "returns false when turns remaining" do
      match_state.update!(current_turn_number: 5, turn_limit: 10)
      expect(match_state.game_over?).to be false
    end

    it "returns true when at turn limit" do
      match_state.update!(current_turn_number: 10, turn_limit: 10)
      expect(match_state.game_over?).to be true
    end

    it "returns true when past turn limit" do
      match_state.update!(current_turn_number: 11, turn_limit: 10)
      expect(match_state.game_over?).to be true
    end
  end

  describe "#increment_turn!" do
    let(:match_state) { create(:match).match_state }

    it "increments current_turn_number by 1" do
      expect {
        match_state.increment_turn!
      }.to change(match_state, :current_turn_number).by(1)
    end

    it "persists the change to the database" do
      match_state.increment_turn!
      expect(match_state.reload.current_turn_number).to eq(1)
    end
  end
end
