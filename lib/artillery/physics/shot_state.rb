# frozen_string_literal: true

module Artillery
  module Physics
    class ShotState
      attr_accessor :time,
                    :mass,
                    :surface_area,
                    :position,     # Artillery::Physics::Vector
                    :velocity,     # Artillery::Physics::Vector
                    :acceleration  # Artillery::Physics::Vector

      def initialize(
        time: 0.0,
        mass: 0.0,
        surface_area: 0.0,
        position: Vector.new,
        velocity: Vector.new,
        acceleration: Vector.new
      )
        @time         = time
        @mass         = mass
        @surface_area = surface_area
        @position     = position
        @velocity     = velocity
        @acceleration = acceleration
      end

      def altitude
        position.z
      end

      def altitude=(val)
        position.z = val
      end

      def copy
        ShotState.new(
          time:         time,
          mass:         mass,
          surface_area: surface_area,
          position:     position.dup,
          velocity:     velocity.dup,
          acceleration: acceleration.dup
        )
      end
    end
  end
end
