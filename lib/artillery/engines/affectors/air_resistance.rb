# frozen_string_literal: true

module Artillery
  module Engines
    module Affectors
      # AirResistance models aerodynamic drag based on current velocity,
      # affecting the projectile’s acceleration negatively in proportion to
      # its speed and surface area.
      #
      # The formula: a_drag = (1/2 * air_density * v² * drag_coeff * area) / mass
      # The force is applied opposite to the projectile’s current velocity.
      class AirResistance < Base
        DEFAULT_AIR_DENSITY = 1.225     # kg/m³ at sea level
        DEFAULT_DRAG_COEFF = 0.47       # spherical / blunt projectile

        attr_reader :state, :tick, :air_density, :drag_coefficient

        def initialize(state, tick, air_density: DEFAULT_AIR_DENSITY, drag_coefficient: DEFAULT_DRAG_COEFF)
          @state = state
          @tick  = tick
          @air_density = air_density
          @drag_coefficient = drag_coefficient
        end

        def call!
          v = state.velocity.magnitude
          return if v == 0

          drag_force_mag = 0.5 * air_density * v**2 * drag_coefficient * state.surface_area
          drag_accel_mag = drag_force_mag / state.mass

          drag_direction = state.velocity.normalize.inverse
          drag_accel_vec = drag_direction * drag_accel_mag

          state.acceleration += drag_accel_vec
        end
      end
    end
  end
end
