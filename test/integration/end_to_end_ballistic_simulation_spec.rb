# frozen_string_literal: true

require "test_helper"

RSpec.describe "End-to-End Ballistic Simulation" do
  let(:player) { create(:player) }
  let(:match) { double("Match", id: 1) }
  let(:random_seed) { 98765 }

  describe "complete QF 18-pounder artillery shot simulation" do
    # Create a complete artillery loadout
    let!(:cartridge) do
      create(
        :cartridge_85mm,
        player:,
        modifiers: {
          'shell_weight_kg' => 8.4,
          'charge_velocity_per_unit' => 50,
          'base_velocity' => 400,
          'caliber_mm' => 84.5,
          'construction' => 'brass'
        }
      )
    end

    let!(:barrel) do
      create(
        :barrel_85mm,
        player:,
        modifiers: {
          'construction' => 'steel',
          'length_meters' => 2.5,
          'wear_factor' => 1.0,
          'velocity_multiplier' => 1.0
        }
      )
    end

    let!(:elevation_dial) do
      create(
        :elevation_dial,
        player:,
        modifiers: {
          'graduations' => 'fine',
          'degrees_per_click' => 1.0,
          'max_elevation' => 45,
          'min_elevation' => 5
        }
      )
    end

    let!(:deflection_screw) do
      create(
        :deflection_screw,
        player:,
        modifiers: {
          'degrees_per_turn' => 0.5,
          'max_deflection' => 8,
          'thread_pitch' => 'standard'
        }
      )
    end

    let!(:breech) do
      create(
        :breech_qf,
        player:,
        modifiers: {
          'breech_type' => 'interrupted_screw',
          'base_loading_time' => 3.0
        }
      )
    end

    let!(:recoil_system) do
      create(
        :recoil_system,
        player:,
        modifiers: {
          'recoil_type' => 'hydropneumatic',
          'recovery_time_base' => 1.5,
          'accuracy_penalty' => 0.3
        }
      )
    end

    let!(:sight) do
      create(
        :optical_sight,
        player:,
        modifiers: {
          'sight_type' => 'telescopic',
          'magnification' => 4.0
        }
      )
    end

    # Collect all mechanisms and create runtimes
    let(:mechanisms) do
      [cartridge, barrel, elevation_dial, deflection_screw, breech, recoil_system, sight]
    end

    let(:runtimes) do
      mechanisms.map { |mech| mech.to_runtime(match:, random_seed:) }
    end

    # Player input for a shot
    let(:player_input) do
      {
        powder_charges: 3,    # Full charge
        elevation: 30,        # 30 clicks on dial
        deflection: 4         # 4 turns on screw (2 degrees right)
      }
    end

    # Create the pipeline resolver
    let(:resolver) do
      Artillery::Mechanisms::PipelineResolver.new(runtimes, player_input)
    end

    describe "mechanism pipeline resolution" do
      it "resolves all mechanisms correctly" do
        context = resolver.resolve

        # Should have calculated base velocity from cartridge
        expect(context.get(:base_initial_velocity)).to be > 0

        # Should have angle from elevation dial
        # 30 clicks * ~0.5 degrees/click (with randomization) = ~14-16 degrees
        expect(context.get(:angle_deg)).to be_between(13, 17)

        # Should have deflection from deflection screw
        # 4 turns * ~0.5 degrees/turn (with randomization) = ~1.9-2.1 degrees
        expect(context.get(:deflection_deg)).to be_between(1.8, 2.2)

        # Should have shell weight and surface area
        expect(context.get(:shell_weight)).to be > 0
        expect(context.get(:surface_area)).to be > 0
      end

      it "converts to ballistic inputs correctly" do
        ballistic_hash = resolver.ballistic_attributes

        expect(ballistic_hash).to include(
          :angle_deg,
          :initial_velocity,
          :shell_weight,
          :deflection_deg,
          :surface_area
        )

        # Validate ranges
        expect(ballistic_hash[:angle_deg]).to be_between(13, 17)
        expect(ballistic_hash[:initial_velocity]).to be > 400
        expect(ballistic_hash[:shell_weight]).to be_between(8, 9)
        expect(ballistic_hash[:deflection_deg]).to be_between(1.8, 2.2)
      end
    end

    describe "ballistic engine simulation" do
      let(:ballistic_input) do
        Artillery::Engines::Inputs::Ballistic3D.new(**resolver.ballistic_attributes)
      end

      let(:engine) do
        # Engine automatically includes gravity and air resistance
        Artillery::Engines::Ballistic3D.new
      end

      it "successfully simulates a complete shot trajectory" do
        result = engine.simulate(ballistic_input)

        # Should have impact coordinates
        expect(result[:impact_xyz]).to be_an(Array)
        expect(result[:impact_xyz].length).to eq(3)

        # Should have flight time
        expect(result[:flight_time]).to be > 0

        # Should have trajectory trace
        expect(result[:trace]).to be_an(Array)
        expect(result[:trace].length).to be > 10  # Should have multiple points
      end

      it "produces realistic trajectory values" do
        result = engine.simulate(ballistic_input)

        # Extract impact point
        impact_x, impact_y, impact_z = result[:impact_xyz]

        # Impact should be at or below ground (simulation continues until z < 0)
        # Last position captured is when z went below 0
        expect(impact_z).to be <  1.0

        # Should have traveled forward (positive x)
        expect(impact_x).to be > 100  # At least 100m range

        # Should have deflection (non-zero y)
        # With ~2 degrees deflection, should have some lateral displacement
        expect(impact_y).not_to eq(0)

        # Flight time should be reasonable (between 1 and 30 seconds)
        expect(result[:flight_time]).to be_between(1, 30)
      end

      it "trajectory follows expected physics" do
        result = engine.simulate(ballistic_input)
        trace = result[:trace]

        # Trace starts after first tick, so first point has moved
        expect(trace.first[0]).to be > 0  # x (should have moved forward)
        expect(trace.first[2]).to be > 0  # z (should still be above ground)

        # Trajectory should go up then down (parabolic)
        z_values = trace.map { |point| point[2] }
        max_altitude = z_values.max

        expect(max_altitude).to be > 50  # Should reach significant height

        # Should have points going up and points coming down
        altitude_increasing = z_values.each_cons(2).any? { |a, b| b > a }
        altitude_decreasing = z_values.each_cons(2).any? { |a, b| b < a }

        expect(altitude_increasing).to be true
        expect(altitude_decreasing).to be true
      end

      it "trajectory includes lateral deflection" do
        result = engine.simulate(ballistic_input)
        trace = result[:trace]

        # Check y-values (lateral displacement from deflection)
        y_values = trace.map { |point| point[1] }

        # Should have consistent lateral movement (all positive or all negative after deflection applied)
        # With positive deflection, y should generally increase
        final_y = y_values.last
        expect(final_y.abs).to be > 1  # Should have at least 1m lateral displacement
      end
    end

    describe "artillery system metrics" do
      it "calculates turn order delay correctly" do
        total_delay = resolver.turn_order_delay

        # Should include breech loading time + recoil recovery time
        # Breech ~3s, Recoil ~1.5s = ~4.5s total
        expect(total_delay).to be_between(4, 5)
      end

      it "provides UI metadata for all mechanisms" do
        metadata = resolver.ui_metadata

        # Should have metadata for 7 mechanisms
        expect(metadata.length).to eq(7)

        # Each should have required fields
        metadata.each do |meta|
          expect(meta).to include(:slot)
        end

        # Check specific slots
        slots = metadata.map { |m| m[:slot] }
        expect(slots).to include(
          :cartridge,
          :barrel,
          :elevation,
          :deflection,
          :breech,
          :recoil_system,
          :sight
        )
      end

      it "provides assistance data from sight mechanism" do
        assistance = resolver.assistance_data

        expect(assistance).to include(
          :estimated_target_distance,
          :sight_magnification,
          :confidence
        )

        expect(assistance[:sight_magnification]).to eq(4.0)
        expect(assistance[:confidence]).to be_between(0, 1)
      end
    end

    describe "different firing solutions" do
      context "high angle shot (indirect fire)" do
        let(:player_input) do
          {
            powder_charges: 3,
            elevation: 40,  # High angle
            deflection: 0
          }
        end

        it "produces longer flight time and higher apex" do
          ballistic_input = Artillery::Engines::Inputs::Ballistic3D.new(**resolver.ballistic_attributes)
          engine = Artillery::Engines::Ballistic3D.new

          result = engine.simulate(ballistic_input)
          trace = result[:trace]
          z_values = trace.map { |point| point[2] }
          max_altitude = z_values.max

          # High angle should achieve significant altitude
          # 40 clicks * ~0.5 deg/click = ~20 degrees
          expect(max_altitude).to be > 50
          expect(result[:flight_time]).to be > 1
        end
      end

      context "low angle shot (direct fire)" do
        let(:player_input) do
          {
            powder_charges: 3,
            elevation: 10,  # Low angle (~10 degrees)
            deflection: 0
          }
        end

        it "produces flatter trajectory" do
          ballistic_input = Artillery::Engines::Inputs::Ballistic3D.new(**resolver.ballistic_attributes)
          engine = Artillery::Engines::Ballistic3D.new

          result = engine.simulate(ballistic_input)
          trace = result[:trace]
          z_values = trace.map { |point| point[2] }
          max_altitude = z_values.max

          # Low angle should have lower max altitude
          expect(max_altitude).to be < 80
          expect(result[:flight_time]).to be < 6
        end
      end

      context "maximum charge" do
        let(:player_input) do
          {
            powder_charges: 5,  # Maximum
            elevation: 30,
            deflection: 0
          }
        end

        it "produces higher velocity and longer range" do
          ballistic_input = Artillery::Engines::Inputs::Ballistic3D.new(**resolver.ballistic_attributes)
          engine = Artillery::Engines::Ballistic3D.new

          result = engine.simulate(ballistic_input)
          impact_x = result[:impact_xyz][0]

          # Higher charge should produce greater range
          expect(ballistic_input.initial_velocity).to be > 600  # Higher velocity
          expect(impact_x).to be > 250  # Longer range
        end
      end

      context "with lateral deflection" do
        let(:player_input) do
          {
            powder_charges: 3,
            elevation: 30,
            deflection: 10  # 10 turns = ~5 degrees (at max deflection limit)
          }
        end

        it "impacts with significant lateral displacement" do
          ballistic_input = Artillery::Engines::Inputs::Ballistic3D.new(**resolver.ballistic_attributes)
          engine = Artillery::Engines::Ballistic3D.new

          result = engine.simulate(ballistic_input)
          _impact_x, impact_y, _impact_z = result[:impact_xyz]

          # Should have significant lateral displacement
          # At max deflection (~8 degrees), y displacement should be noticeable
          expect(impact_y.abs).to be > 20
        end
      end
    end

    describe "randomization consistency" do
      it "produces identical results with same random seed" do
        # First simulation
        runtimes1 = mechanisms.map { |mech| mech.to_runtime(match:, random_seed:) }
        resolver1 = Artillery::Mechanisms::PipelineResolver.new(runtimes1, player_input)
        input1 = Artillery::Engines::Inputs::Ballistic3D.new(**resolver1.ballistic_attributes)

        # Second simulation with same seed
        runtimes2 = mechanisms.map { |mech| mech.to_runtime(match:, random_seed:) }
        resolver2 = Artillery::Mechanisms::PipelineResolver.new(runtimes2, player_input)
        input2 = Artillery::Engines::Inputs::Ballistic3D.new(**resolver2.ballistic_attributes)

        # Should produce identical inputs
        expect(input1.to_h).to eq(input2.to_h)
      end

      it "produces different results with different random seed" do
        # First simulation
        runtimes1 = mechanisms.map { |mech| mech.to_runtime(match:, random_seed: 12345) }
        resolver1 = Artillery::Mechanisms::PipelineResolver.new(runtimes1, player_input)
        input1 = Artillery::Engines::Inputs::Ballistic3D.new(**resolver1.ballistic_attributes)

        # Second simulation with different seed
        runtimes2 = mechanisms.map { |mech| mech.to_runtime(match:, random_seed: 99999) }
        resolver2 = Artillery::Mechanisms::PipelineResolver.new(runtimes2, player_input)
        input2 = Artillery::Engines::Inputs::Ballistic3D.new(**resolver2.ballistic_attributes)

        # Should produce different inputs (due to variance)
        expect(input1.initial_velocity).not_to eq(input2.initial_velocity)
      end
    end
  end
end
