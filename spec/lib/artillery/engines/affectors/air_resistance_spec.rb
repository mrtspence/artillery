# frozen_string_literal: true

require "spec_helper"

RSpec.describe Artillery::Engines::Affectors::AirResistance do
  let(:tick) { 0.05 }

  def build_state(velocity:, acceleration:, surface_area:, mass:)
    Artillery::Physics::ShotState.new(
      time: 0.0,
      mass: mass,
      surface_area: surface_area,
      position: Artillery::Physics::Vector.new(0, 0, 0),
      velocity: velocity,
      acceleration: acceleration
    )
  end

  describe "#call!" do
    context "when velocity is zero" do
      it "applies no drag force" do
        state = build_state(
          velocity: Artillery::Physics::Vector.new(0, 0, 0),
          acceleration: Artillery::Physics::Vector.new(0, 0, 0),
          surface_area: 1.0,
          mass: 1.0
        )

        described_class.new(state, tick).call!

        expect(state.acceleration.to_a).to eq([0, 0, 0])
      end
    end

    context "when velocity is in +x axis" do
      it "applies acceleration opposite to velocity direction" do
        velocity = Artillery::Physics::Vector.new(10.0, 0, 0) # speed = 10 m/s
        state = build_state(
          velocity: velocity,
          acceleration: Artillery::Physics::Vector.new(0, 0, 0),
          surface_area: 0.01,  # m²
          mass: 1.0            # kg
        )

        affector = described_class.new(state, tick)
        affector.call!

        # F_drag = 0.5 * ρ * v² * Cd * A
        expected_drag_force = 0.5 * 1.225 * 100 * 0.47 * 0.01
        expected_accel = -expected_drag_force / 1.0  # a = F / m

        expect(state.acceleration.x).to be_within(0.0001).of(expected_accel)
        expect(state.acceleration.y).to eq(0)
        expect(state.acceleration.z).to eq(0)
      end
    end
  end
end
