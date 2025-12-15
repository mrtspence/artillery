# frozen_string_literal: true

require "test_helper"

RSpec.describe MatchPlayer, type: :model do
  describe "associations" do
    let(:match) { create(:match) }
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }
    subject { match.add_player!(player, loadout) }

    it { is_expected.to belong_to(:match) }
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:player_loadout) }
    it { is_expected.to have_many(:turns).dependent(:destroy) }
  end

  describe "validations" do
    let(:match) { create(:match) }
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }

    before { match.add_player!(player, loadout) }
    subject { match.match_players.first }

    it { is_expected.to validate_uniqueness_of(:player_id).scoped_to(:match_id) }
    it { is_expected.to validate_presence_of(:turn_order) }
    it { is_expected.to validate_numericality_of(:turn_order).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_uniqueness_of(:turn_order).scoped_to(:match_id) }
    it { is_expected.to validate_presence_of(:score) }
    it { is_expected.to validate_numericality_of(:score).is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    let(:match) { create(:match) }
    let(:player1) { create(:player, username: "player_1") }
    let(:player2) { create(:player, username: "player_2") }
    let(:player3) { create(:player, username: "player_3") }
    let(:loadout1) { create(:player_loadout, player: player1) }
    let(:loadout2) { create(:player_loadout, player: player2) }
    let(:loadout3) { create(:player_loadout, player: player3) }

    before do
      match.add_player!(player1, loadout1, is_host: true)
      match.add_player!(player2, loadout2)
      match.add_player!(player3, loadout3)
    end

    describe ".by_turn_order" do
      it "returns players ordered by turn_order" do
        players = match.match_players.by_turn_order.map(&:player)
        expect(players).to eq([player1, player2, player3])
      end
    end

    describe ".hosts" do
      it "returns only host players" do
        hosts = match.match_players.hosts
        expect(hosts.count).to eq(1)
        expect(hosts.first.player).to eq(player1)
      end
    end
  end
end
