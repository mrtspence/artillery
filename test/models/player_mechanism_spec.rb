# frozen_string_literal: true

require "test_helper"

RSpec.describe PlayerMechanism, type: :model do
  describe "associations" do
    subject { build(:cartridge_85mm) }

    it { is_expected.to belong_to(:player) }
    it { is_expected.to have_many(:player_loadout_slots).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:player_loadouts).through(:player_loadout_slots) }
  end

  describe "validations" do
    subject { build(:cartridge_85mm) }

    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_presence_of(:slot_key) }
    it { is_expected.to validate_presence_of(:priority) }
    it { is_expected.to validate_numericality_of(:upgrade_level).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:priority).only_integer }
  end

  describe "#to_runtime" do
    let(:player) { create(:player) }
    let(:mechanism) { create(:cartridge_85mm, player:) }
    let(:match) { double("Match", id: 1) }
    let(:random_seed) { 12345 }

    it "creates runtime with correct parameters" do
      runtime = mechanism.to_runtime(match:, random_seed:)

      expect(runtime).to be_a(Artillery::Mechanisms::Runtimes::Cartridge85mmRuntime)
      expect(runtime.mechanism).to eq(mechanism)
      expect(runtime.match).to eq(match)
    end
  end

  describe "#input_keys" do
    let(:mechanism) { build(:cartridge_85mm) }

    it "returns array of input keys for concrete mechanism" do
      expect(mechanism.input_keys).to eq([:powder_charges])
    end
  end

  describe "#output_keys" do
    let(:mechanism) { build(:cartridge_85mm) }

    it "returns array of output keys for concrete mechanism" do
      expect(mechanism.output_keys).to contain_exactly(
        :base_initial_velocity,
        :shell_weight,
        :surface_area,
        :caliber_mm
      )
    end
  end
end
