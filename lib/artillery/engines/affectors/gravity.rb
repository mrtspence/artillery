# frozen_string_literal: true

module Artillery
  module Engines
    module Affectors
      class Gravity < Base
        STANDARD_GRAVITY = 9.81

        attr_reader :state, :tick, :gravity

        def initialize(state, tick, gravity: STANDARD_GRAVITY)
          @state   = state
          @tick    = tick
          @gravity = gravity
        end

        def call!
          state.acceleration.z -= gravity
        end
      end
    end
  end
end
