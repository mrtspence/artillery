# frozen_string_literal: true

require "test_helper"

RSpec.describe PlayerLoadout, "platform validation", type: :model do
  let(:player) { create(:player) }

  describe "validations" do
    context "with qf_18_pounder platform" do
      it "can be saved without required mechanisms (draft state)" do
        loadout = create(:player_loadout, player:, platform_type: "qf_18_pounder")
        expect(loadout).to be_persisted
        expect(loadout).to be_valid
      end

      it "is valid with all required mechanisms" do
        complete_loadout = create(:player_loadout, :qf_18_pounder_complete, player:)
        expect(complete_loadout).to be_valid
      end
    end

    context "with unknown platform type" do
      it "can be saved with unknown platform (will fail valid_for_match?)" do
        loadout = create(:player_loadout, player:, platform_type: "nonexistent_platform")
        expect(loadout).to be_persisted
        expect(loadout).to be_valid
      end
    end
  end

  describe "#platform" do
    let(:loadout) { build(:player_loadout, player:, platform_type: "qf_18_pounder") }

    it "returns platform class" do
      expect(loadout.platform).to eq(Artillery::Platforms::Qf18Pounder)
    end

    it "raises error for unknown platform" do
      loadout.platform_type = "unknown"

      expect {
        loadout.platform
      }.to raise_error(Artillery::Platforms::UnknownPlatformError)
    end
  end

  describe "#missing_required_slots" do
    context "with no mechanisms" do
      it "returns all required slots" do
        loadout = create(:player_loadout, player:, platform_type: "qf_18_pounder")
        missing = loadout.missing_required_slots

        expect(missing).to include(:elevation, :barrel, :cartridge, :deflection, :breech, :recoil_system, :sight)
        expect(missing.length).to eq(7)
      end
    end

    context "with some mechanisms" do
      let(:loadout) do
        elevation = create(:elevation_dial, player:)
        barrel = create(:barrel_85mm, player:)
        cartridge = create(:cartridge_85mm, player:)
        breech = create(:breech_qf, player:)
        recoil = create(:recoil_system, player:)

        loadout = create(:player_loadout, player:, platform_type: "qf_18_pounder")

        [elevation, barrel, cartridge, breech, recoil].each do |mech|
          create(:player_loadout_slot,
            player_loadout: loadout,
            player_mechanism: mech,
            slot_key: mech.slot_key
          )
        end

        loadout.reload
      end

      it "returns only unfilled required slots" do
        missing = loadout.missing_required_slots

        expect(missing).not_to include(:elevation, :barrel, :cartridge, :breech, :recoil_system)
        expect(missing).to include(:deflection, :sight)
        expect(missing.length).to eq(2)
      end
    end
  end

  describe "#valid_for_match?" do
    it "returns false when missing required slots" do
      loadout = create(:player_loadout, player:, platform_type: "qf_18_pounder")
      expect(loadout.valid_for_match?).to be false
    end

    it "returns false for unknown platform" do
      loadout = create(:player_loadout, player:, platform_type: "nonexistent_platform")
      expect(loadout.valid_for_match?).to be false
    end

    it "returns true when all slots filled and valid" do
      complete_loadout = create(:player_loadout, :qf_18_pounder_complete, player:)
      expect(complete_loadout.valid_for_match?).to be true
    end
  end

  describe "#platform_validation_errors" do
    it "returns errors for incomplete loadout" do
      loadout = create(:player_loadout, player:, platform_type: "qf_18_pounder")
      errors = loadout.platform_validation_errors

      expect(errors).not_to be_empty
      expect(errors.join).to include("Required slot")
    end

    it "returns empty array for complete loadout" do
      complete_loadout = create(:player_loadout, :qf_18_pounder_complete, player:)
      errors = complete_loadout.platform_validation_errors

      expect(errors).to be_empty
    end

    it "returns error for unknown platform" do
      loadout = create(:player_loadout, player:, platform_type: "nonexistent_platform")
      errors = loadout.platform_validation_errors

      expect(errors).to include(/Unknown platform/)
    end
  end

  describe "#allowed_mechanism_types_for_slot" do
    let(:loadout) { build(:player_loadout, player:, platform_type: "qf_18_pounder") }

    it "returns allowed types for barrel slot" do
      allowed = loadout.allowed_mechanism_types_for_slot(:barrel)

      expect(allowed).to include("PlayerMechanisms::Barrel85mm")
    end

    it "returns allowed types for elevation slot" do
      allowed = loadout.allowed_mechanism_types_for_slot(:elevation)

      expect(allowed).to include("PlayerMechanisms::ElevationDial")
    end

    it "returns empty array for unknown slot" do
      allowed = loadout.allowed_mechanism_types_for_slot(:unknown_slot)

      expect(allowed).to be_empty
    end
  end
end
