# frozen_string_literal: true

require "spec_helper"

RSpec.describe Artillery::Engines::Affectors::Gravity do
  let(:tick) { 0.05 }

  def build_state(acceleration:)
    Artillery::Physics::ShotState.new(
      time: 0.0,
      mass: 1.0,
      surface_area: 1.0,
      position: Artillery::Physics::Vector.new(0, 0, 0),
      velocity: Artillery::Physics::Vector.new(0, 0, 0),
      acceleration: acceleration
    )
  end

  describe ".call" do
    context "with default gravity" do
      it "applies STANDARD_GRAVITY to z acceleration" do
        state = build_state(acceleration: Artillery::Physics::Vector.new(0, 0, 0))

        described_class.call(state, tick)

        expect(state.acceleration.z).to eq(-described_class::STANDARD_GRAVITY)
      end
    end

    context "with custom gravity" do
      it "applies custom gravity to z acceleration" do
        state = build_state(acceleration: Artillery::Physics::Vector.new(0, 0, 0))

        described_class.call(state, tick, gravity: 1.62)

        expect(state.acceleration.z).to eq(-1.62)
      end
    end
  end
end
