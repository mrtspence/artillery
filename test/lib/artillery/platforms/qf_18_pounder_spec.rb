# frozen_string_literal: true

require "test_helper"

RSpec.describe Artillery::Platforms::Qf18Pounder do
  describe ".key" do
    it "returns platform key" do
      expect(described_class.key).to eq("qf_18_pounder")
    end
  end

  describe ".name" do
    it "returns platform name" do
      expect(described_class.name).to eq("Ordnance QF 18-pounder")
    end
  end

  describe ".description" do
    it "returns platform description" do
      description = described_class.description
      expect(description).to be_a(String)
      expect(description).to include("British")
    end
  end

  describe ".engine_type" do
    it "returns ballistic_3d" do
      expect(described_class.engine_type).to eq("ballistic_3d")
    end
  end

  describe ".slot_requirements" do
    it "defines all required slots" do
      requirements = described_class.slot_requirements

      expect(requirements).to be_an(Array)
      slot_keys = requirements.map(&:slot_key)

      expect(slot_keys).to include(
        :elevation, :deflection, :cartridge, :barrel,
        :breech, :recoil_system, :sight
      )
    end

    it "marks all slots as required" do
      requirements = described_class.slot_requirements

      requirements.each do |req|
        expect(req.required?).to be true
      end
    end

    it "specifies allowed mechanism types" do
      requirements = described_class.slot_requirements
      barrel_req = requirements.find { |r| r.slot_key == :barrel }

      expect(barrel_req.allowed_types).to include("PlayerMechanisms::Edwardian::Barrel85mm")
    end

    it "has descriptions for each slot" do
      requirements = described_class.slot_requirements

      requirements.each do |req|
        expect(req.description).to be_a(String)
        expect(req.description.length).to be > 10
      end
    end
  end

  describe ".slot_requirement_for" do
    it "returns slot requirement by key" do
      req = described_class.slot_requirement_for(:barrel)

      expect(req).to be_a(Artillery::Platforms::SlotRequirement)
      expect(req.slot_key).to eq(:barrel)
    end

    it "returns nil for unknown slot" do
      req = described_class.slot_requirement_for(:unknown_slot)

      expect(req).to be_nil
    end
  end

  describe ".required_slot_keys" do
    it "returns all required slot keys" do
      keys = described_class.required_slot_keys

      expect(keys).to include(:elevation, :barrel, :cartridge)
    end
  end

  describe ".mechanism_allowed_in_slot?" do
    let(:barrel_85mm) { build(:barrel_85mm) }

    it "allows compatible mechanisms" do
      expect(described_class.mechanism_allowed_in_slot?(:barrel, barrel_85mm)).to be true
    end

    it "rejects mechanism in wrong slot" do
      # Barrel can't go in elevation slot
      expect(described_class.mechanism_allowed_in_slot?(:elevation, barrel_85mm)).to be false
    end

    it "rejects unknown slot" do
      expect(described_class.mechanism_allowed_in_slot?(:nonexistent, barrel_85mm)).to be false
    end
  end

  describe ".validate_loadout" do
    let(:player) { create(:player) }

    context "with valid complete loadout" do
      let(:loadout) { create(:player_loadout, :qf_18_pounder_complete, player:) }

      it "returns no errors" do
        errors = described_class.validate_loadout(loadout)
        expect(errors).to be_empty
      end
    end

    context "with wrong platform_type" do
      let(:loadout) { build(:player_loadout, player:, platform_type: "different_platform") }

      it "returns platform type error" do
        errors = described_class.validate_loadout(loadout)
        expect(errors).to include(/Loadout platform_type must be 'qf_18_pounder'/)
      end
    end

    context "with missing required slot" do
      let(:loadout) { create(:player_loadout, player:, platform_type: "qf_18_pounder") }

      it "returns error for missing slot" do
        errors = described_class.validate_loadout(loadout)
        expect(errors).to include(/Required slot 'elevation' is not filled/)
      end
    end

    context "with partially filled loadout" do
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

      it "returns errors for each missing slot" do
        errors = described_class.validate_loadout(loadout)

        # Should have errors for missing: deflection, sight
        expect(errors.length).to eq(2)
        expect(errors).to include(/Required slot 'deflection' is not filled/)
      end
    end
  end

  describe ".ui_characteristics" do
    it "returns characteristics hash" do
      chars = described_class.ui_characteristics

      expect(chars).to include(:faction, :role, :crew_size)
      expect(chars[:faction]).to eq("Edwardian")
    end
  end
end
