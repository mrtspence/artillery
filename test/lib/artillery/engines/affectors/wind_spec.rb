require "spec_helper"

RSpec.describe Artillery::Engines::Affectors::Wind do
  let(:tick) { 0.05 }

  it "applies wind scaled by surface area to acceleration" do
    state = Artillery::Physics::ShotState.new(
      time: 0.0,
      mass: 1.0,
      surface_area: 2.0,
      position: Artillery::Physics::Vector.new(0, 0, 0),
      velocity: Artillery::Physics::Vector.new(0, 0, 0),
      acceleration: Artillery::Physics::Vector.new(0, 0, 0)
    )

    wind_vector = Artillery::Physics::Vector.new(0.5, 0.0, 0.0) # wind = 0.5 m/s² per m²
    described_class.new(state, tick, wind_vector).call!

    expect(state.acceleration.to_a).to eq([1.0, 0.0, 0.0]) # wind * area
  end
end
