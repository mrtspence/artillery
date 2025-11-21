# frozen_string_literal: true

module Artillery
  module Engines
    module Affectors
      # Wind applies acceleration to a projectile in proportion to its surface area.
      # The supplied wind_vector is understood as acceleration per square meter.
      class Wind < Base
        def initialize(state, tick, wind_vector)
          @state = state
          @tick = tick
          @wind_vector = wind_vector
        end

        def call!
          area_adjusted_accel = wind_vector.scale(state.surface_area)
          state.acceleration.add!(area_adjusted_accel)
        end

        private

        attr_reader :state, :tick, :wind_vector
      end
    end
  end
end
