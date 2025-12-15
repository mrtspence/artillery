# frozen_string_literal: true

require "test_helper"

RSpec.describe Match, type: :model do
  describe "associations" do
    subject { create(:match) }

    it { is_expected.to belong_to(:current_player).class_name('Player').optional }
    it { is_expected.to have_one(:match_state).dependent(:destroy) }
    it { is_expected.to have_one(:map).dependent(:destroy) }
    it { is_expected.to have_many(:match_players).dependent(:destroy) }
    it { is_expected.to have_many(:players).through(:match_players) }
    it { is_expected.to have_many(:turns).dependent(:destroy) }
  end

  describe "validations" do
    subject { create(:match) }

    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[setup in_progress completed abandoned]) }
    it { is_expected.to validate_presence_of(:lobby_code) }
    it { is_expected.to validate_uniqueness_of(:lobby_code) }
    it { is_expected.to validate_length_of(:lobby_code).is_equal_to(6) }
  end

  describe "callbacks" do
    describe "lobby code generation" do
      it "generates a 6-character lobby code on create" do
        match = Match.create!
        expect(match.lobby_code).to be_present
        expect(match.lobby_code.length).to eq(6)
        expect(match.lobby_code).to match(/^[A-Z0-9]{6}$/)
      end

      it "generates unique lobby codes" do
        match1 = Match.create!
        match2 = Match.create!
        expect(match1.lobby_code).not_to eq(match2.lobby_code)
      end

      it "does not override manually set lobby code" do
        match = Match.create!(lobby_code: "CUSTOM")
        expect(match.lobby_code).to eq("CUSTOM")
      end
    end

    describe "match initialization" do
      it "creates a match_state after create" do
        match = Match.create!
        expect(match.match_state).to be_present
        expect(match.match_state.current_turn_number).to eq(0)
        expect(match.match_state.turn_limit).to eq(10)
      end

      it "creates a map after create" do
        match = Match.create!
        expect(match.map).to be_present
        expect(match.map.name).to eq("Default Map")
        expect(match.map.width).to eq(1000)
        expect(match.map.height).to eq(1000)
      end
    end
  end

  describe "scopes" do
    let!(:setup_match) { create(:match, status: 'setup') }
    let!(:in_progress_match) { create(:match, status: 'in_progress') }
    let!(:completed_match) { create(:match, status: 'completed') }
    let!(:abandoned_match) { create(:match, status: 'abandoned') }

    describe ".in_setup" do
      it "returns only setup matches" do
        expect(Match.in_setup).to contain_exactly(setup_match)
      end
    end

    describe ".in_progress" do
      it "returns only in_progress matches" do
        expect(Match.in_progress).to contain_exactly(in_progress_match)
      end
    end

    describe ".completed" do
      it "returns only completed matches" do
        expect(Match.completed).to contain_exactly(completed_match)
      end
    end

    describe ".active" do
      it "returns setup and in_progress matches" do
        expect(Match.active).to contain_exactly(setup_match, in_progress_match)
      end
    end
  end

  describe "#add_player!" do
    let(:match) { create(:match) }
    let(:player) { create(:player) }
    let(:loadout) { create(:player_loadout, player: player) }

    context "when match is in setup phase" do
      it "adds player to match" do
        expect {
          match.add_player!(player, loadout)
        }.to change(match.match_players, :count).by(1)
      end

      it "sets correct turn order" do
        match_player = match.add_player!(player, loadout)
        expect(match_player.turn_order).to eq(0)
      end

      it "can mark player as host" do
        match_player = match.add_player!(player, loadout, is_host: true)
        expect(match_player.is_host).to be true
      end
    end

    context "when match is not in setup phase" do
      before { match.update!(status: 'in_progress') }

      it "raises MatchException" do
        expect {
          match.add_player!(player, loadout)
        }.to raise_error(MatchException, "Match is not in setup phase")
      end
    end

    context "when match is full" do
      before do
        Match::MAX_PLAYERS.times do |i|
          p = create(:player, username: "player_#{i}")
          l = create(:player_loadout, player: p)
          match.add_player!(p, l)
        end
      end

      it "raises MatchException" do
        new_player = create(:player)
        new_loadout = create(:player_loadout, player: new_player)

        expect {
          match.add_player!(new_player, new_loadout)
        }.to raise_error(MatchException, "Match is full")
      end
    end

    context "when player already in match" do
      before { match.add_player!(player, loadout) }

      it "raises MatchException" do
        expect {
          match.add_player!(player, loadout)
        }.to raise_error(MatchException, "Player already in match")
      end
    end
  end

  describe "#start!" do
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

      it "changes status to in_progress" do
        match.start!
        expect(match.status).to eq('in_progress')
      end

      it "sets first player as current_player" do
        match.start!
        expect(match.current_player).to eq(player1)
      end
    end

    context "with insufficient players" do
      before { match.add_player!(player1, loadout1) }

      it "raises MatchException" do
        expect {
          match.start!
        }.to raise_error(MatchException, "Need at least #{Match::MIN_PLAYERS} players")
      end
    end

    context "when match already started" do
      before do
        match.add_player!(player1, loadout1)
        match.add_player!(player2, loadout2)
        match.start!
      end

      it "raises MatchException" do
        expect {
          match.start!
        }.to raise_error(MatchException, "Match already started")
      end
    end
  end

  describe "#complete!" do
    let(:match) { create(:match, status: 'in_progress') }

    it "changes status to completed" do
      match.complete!
      expect(match.status).to eq('completed')
    end

    context "when match is not in progress" do
      let(:match) { create(:match, status: 'setup') }

      it "raises MatchException" do
        expect {
          match.complete!
        }.to raise_error(MatchException, "Match is not in progress")
      end
    end
  end

  describe "#abandon!" do
    let(:match) { create(:match) }

    it "changes status to abandoned" do
      match.abandon!
      expect(match.status).to eq('abandoned')
    end

    context "when match is already completed" do
      let(:match) { create(:match, status: 'completed') }

      it "raises MatchException" do
        expect {
          match.abandon!
        }.to raise_error(MatchException, "Match already completed")
      end
    end
  end

  describe "#current_match_player" do
    let(:match) { create(:match) }
    let(:player1) { create(:player, username: "player_1") }
    let(:player2) { create(:player, username: "player_2") }
    let(:loadout1) { create(:player_loadout, player: player1) }
    let(:loadout2) { create(:player_loadout, player: player2) }

    before do
      match.add_player!(player1, loadout1)
      match.add_player!(player2, loadout2)
      match.start!
    end

    it "returns the MatchPlayer for the current player" do
      current = match.current_match_player
      expect(current).to be_a(MatchPlayer)
      expect(current.player).to eq(player1)
    end
  end
end
