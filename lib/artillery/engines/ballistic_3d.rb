# frozen_string_literal: true

module Artillery
  module Engines
    class Ballistic3D
      TICK = 0.05

      def initialize(before_tick_hooks: [], after_tick_hooks: [], affectors: [])
        @before_hooks = before_tick_hooks
        @after_hooks = after_tick_hooks
        @affectors = affectors
      end

      def simulate(input)
        state = initial_state(input)
        history = []

        while state.position.z > 0
          @before_hooks.each { |hook| hook.call!(state, TICK) }

          @affectors.each { |affector| affector.call!(state, TICK) }

          integrate!(state)

          @after_hooks.each { |hook| hook.call!(state, TICK) }

          history << state.copy
        end

        {
          impact_xyz: state.position.to_a.map { |v| v.round(2) },
          flight_time: state.time.round(2),
          trace: history.map(&:position).map(&:to_a)
        }
      end

      private

      def integrate!(state)
        state.velocity = state.velocity + (state.acceleration * TICK)
        state.position = state.position + (state.velocity * TICK)
        state.time += TICK
        state.acceleration = Physics::Vector.new(0, 0, 0) # reset forces
      end

      def initial_state(input)
        angle = deg_to_rad(input.angle_deg)
        defl = deg_to_rad(input.deflection_deg)

        vx = input.initial_velocity * Math.cos(angle) * Math.cos(defl)
        vy = input.initial_velocity * Math.cos(angle) * Math.sin(defl)
        vz = input.initial_velocity * Math.sin(angle)

        Physics::ShotState.new(
          time: 0.0,
          mass: input.shell_weight,
          surface_area: input.surface_area || 0,
          position: Physics::Vector.new(0, 0, 0),
          velocity: Physics::Vector.new(vx, vy, vz),
          acceleration: Physics::Vector.new(0, 0, 0)
        )
      end

      def deg_to_rad(d)
        d * Math::PI / 180
      end
    end
  end
end
