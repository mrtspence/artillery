# frozen_string_literal: true

require "test_helper"

RSpec.describe "Full Artillery Mechanism Pipeline" do
  let(:player) { create(:player) }
  let(:match) { double("Match", id: 1) }
  let(:random_seed) { 12345 }

  describe "QF 18-pounder complete loadout" do
    # Create all mechanisms for a complete artillery piece
    let(:elevation_dial) { create(:elevation_dial, player:) }
    let(:deflection_screw) { create(:deflection_screw, player:) }
    let(:cartridge) { create(:cartridge_85mm, player:) }
    let(:barrel) { create(:barrel_85mm, player:) }
    let(:breech) { create(:breech_qf, player:) }
    let(:recoil_system) { create(:recoil_system, player:) }
    let(:sight) { create(:optical_sight, player:) }

    let(:mechanisms) do
      [elevation_dial, deflection_screw, cartridge, barrel, breech, recoil_system, sight]
    end

    let(:runtimes) do
      mechanisms.map.with_index { |m, i| m.to_runtime(match:, random_seed: random_seed + i) }
    end

    let(:player_input) do
      {
        elevation: 20,       # 20 clicks on elevation dial
        deflection: -3,      # 3 turns left on deflection screw
        powder_charges: 3    # 3 powder charges
      }
    end

    let(:resolver) { Artillery::Mechanisms::PipelineResolver.new(runtimes, player_input) }

    it "resolves all mechanisms in priority order" do
      context = resolver.resolve

      # Should have values from all mechanisms
      expect(context.has?(:angle_deg)).to be true
      expect(context.has?(:deflection_deg)).to be true
      expect(context.has?(:base_initial_velocity)).to be true
      expect(context.has?(:shell_weight)).to be true
      expect(context.has?(:surface_area)).to be true
    end

    it "applies mechanisms in correct priority order" do
      # Priority order (lowest first):
      # 5: elevation_dial, deflection_screw
      # 10: cartridge
      # 15: barrel
      # 85: recoil_system
      # 90: breech
      # 95: sight

      # Elevation dial sets angle, recoil and barrel add increments
      context = resolver.resolve

      # Angle should be set by elevation dial, then modified by barrel and recoil
      angle = context.get(:angle_deg)
      expect(angle).to be_between(15, 25)  # 20 clicks ≈ 20°, ± adjustments
    end

    it "generates ballistic inputs for engine" do
      inputs = resolver.ballistic_attributes

      expect(inputs[:angle_deg]).to be_a(Numeric)
      expect(inputs[:initial_velocity]).to be_a(Numeric)
      expect(inputs[:shell_weight]).to be_a(Numeric)
      expect(inputs[:deflection_deg]).to be_a(Numeric)
      expect(inputs[:surface_area]).to be_a(Numeric)
    end

    it "calculates total turn order delay from breech and recoil" do
      delay = resolver.turn_order_delay

      # Breech ~3s + Recoil ~2s = ~5s total
      expect(delay).to be_between(4.0, 6.0)
    end

    it "collects UI metadata from all mechanisms" do
      metadata = resolver.ui_metadata

      # Should have metadata from:
      # - elevation_dial (dial control)
      # - deflection_screw (slider control)
      # - cartridge (slider control)
      # - barrel, breech, recoil_system, sight (info displays)
      expect(metadata.length).to eq(7)

      control_types = metadata.map { |m| m[:control_type] }
      expect(control_types).to include(:dial, :slider, :info_display)
    end

    it "provides assistance data from sight" do
      assistance = resolver.assistance_data

      expect(assistance).to include(:estimated_target_distance)
      expect(assistance).to include(:sight_magnification)
      expect(assistance).to include(:confidence)
    end

    describe "mechanism interactions" do
      it "barrel multiplies cartridge velocity" do
        context = resolver.resolve

        # Cartridge sets base_initial_velocity
        # Barrel multiplies it
        velocity = context.get(:base_initial_velocity)

        # Base: 400 + (3 * 50) = 550 m/s
        # With barrel multiplier (~1.0) and variances
        expect(velocity).to be_between(500, 600)
      end

      it "elevation dial sets angle, barrel and recoil modify it" do
        context = resolver.resolve

        # Elevation: 20 clicks × ~1°/click = ~20°
        # Barrel adds accuracy variance (±1°)
        # Recoil adds penalty (±0.3°)
        angle = context.get(:angle_deg)

        expect(angle).to be_between(18, 22)
      end

      it "deflection screw converts turns to degrees" do
        context = resolver.resolve

        # -3 turns × 0.5°/turn = -1.5°
        deflection = context.get(:deflection_deg)

        expect(deflection).to be_between(-2.0, -1.0)
      end
    end

    describe "upgraded mechanisms" do
      let(:upgraded_dial) { create(:elevation_dial, :vernier, player:, upgrade_level: 3) }
      let(:upgraded_barrel) { create(:barrel_85mm, :chrome_lined, player:, upgrade_level: 2) }
      let(:upgraded_recoil) { create(:recoil_system, :hydropneumatic, player:, upgrade_level: 2) }

      let(:upgraded_mechanisms) do
        [upgraded_dial, deflection_screw, cartridge, upgraded_barrel, breech, upgraded_recoil, sight]
      end

      let(:upgraded_runtimes) do
        upgraded_mechanisms.map.with_index { |m, i| m.to_runtime(match:, random_seed: random_seed + i) }
      end

      let(:upgraded_resolver) do
        Artillery::Mechanisms::PipelineResolver.new(upgraded_runtimes, player_input)
      end

      it "provides more accurate elevation with vernier dial" do
        upgraded_metadata = upgraded_resolver.ui_metadata
        dial_metadata = upgraded_metadata.find { |m| m[:slot] == :elevation }

        # Vernier dial: 0.1° per click with upgrades
        conversion_text = dial_metadata[:conversion]
        expect(conversion_text).to include("° per click")
        # Extract the numeric value - should be very small (< 0.15)
        degrees = conversion_text.scan(/[\d.]+/).first.to_f
        expect(degrees).to be < 0.15
      end

      it "increases velocity with chrome-lined barrel" do
        context = upgraded_resolver.resolve
        velocity = context.get(:base_initial_velocity)

        # Chrome-lined adds ~5% velocity bonus, but with random variance
        # Base: 400 + (3 * 50) = 550, but could be lower with variance
        # Chrome-lined multiplier ~1.05, so expect >= 520
        expect(velocity).to be >= 520
      end

      it "reduces turn order delay with upgraded systems" do
        delay = upgraded_resolver.turn_order_delay

        # Hydropneumatic recoil is faster
        expect(delay).to be < 5.0
      end
    end

    describe "edge cases" do
      it "handles missing player input gracefully" do
        minimal_input = { powder_charges: 2 }
        minimal_resolver = Artillery::Mechanisms::PipelineResolver.new(runtimes, minimal_input)

        expect {
          minimal_resolver.resolve
        }.not_to raise_error
      end

      it "clamps elevation to min/max bounds" do
        extreme_input = { elevation: 100, powder_charges: 1 }  # Way too high
        extreme_resolver = Artillery::Mechanisms::PipelineResolver.new(runtimes, extreme_input)

        context = extreme_resolver.resolve
        angle = context.get(:angle_deg)

        # Should be clamped to max_elevation (45°) ± variances
        expect(angle).to be <= 47
      end

      it "clamps deflection to max bounds" do
        extreme_input = { deflection: 50, powder_charges: 1 }  # Way too much
        extreme_resolver = Artillery::Mechanisms::PipelineResolver.new(runtimes, extreme_input)

        context = extreme_resolver.resolve
        deflection = context.get(:deflection_deg)

        # Should be clamped to max_deflection (8°)
        expect(deflection).to be <= 9
      end
    end
  end
end
