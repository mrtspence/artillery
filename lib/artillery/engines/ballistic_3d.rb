# frozen_string_literal: true

# app/lib/artillery/engines/ballistic_3d.rb
module Artillery
  module Engines
    class Ballistic3D
      GRAVITY = 9.81

      def simulate(ballistic_input)
        attrs = ballistic_input.to_h

        angle_rad    = deg_to_rad(attrs[:angle_deg])
        deflection   = deg_to_rad(attrs[:deflection_deg])
        velocity     = attrs[:initial_velocity]
        shell_weight = attrs[:shell_weight]
        aoe_radius   = attrs[:area_of_effect]

        vx = velocity * Math.cos(angle_rad) * Math.cos(deflection)
        vy = velocity * Math.cos(angle_rad) * Math.sin(deflection)
        vz = velocity * Math.sin(angle_rad)

        time = (2 * vz) / GRAVITY

        x_impact = vx * time
        y_impact = vy * time

        {
          impact_xyz: [x_impact.round(2), y_impact.round(2), 0.0],
          flight_time: time.round(2),
          area_of_effect: aoe_radius,
          debug: {
            components: { vx: vx, vy: vy, vz: vz },
            shell_weight: shell_weight,
            velocity: velocity
          }
        }
      end

      private

      def deg_to_rad(deg)
        deg * Math::PI / 180.0
      end
    end
  end
end
