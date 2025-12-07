module Artillery
  module Engines
    module Hooks
      module Flight
        class Parachute < FlightHook
          def initialize(deploy_altitude: nil, deploy_after_time: nil, deploy_after_distance: nil)
            @deploy_altitude = deploy_altitude
            @deploy_after_time = deploy_after_time
            @deploy_after_distance = deploy_after_distance
            @deployed = false
            @starting_position = nil
          end

          def call!(state, tick)
            return if @deployed

            @starting_position ||= state.position.dup

            should_deploy =
              (@deploy_altitude && state.altitude <= @deploy_altitude) ||
              (@deploy_after_time && state.time >= @deploy_after_time) ||
              (@deploy_after_distance && total_distance(state) >= @deploy_after_distance)

            if should_deploy
              @deployed = true
              state.velocity.scale!(0.3)  # slam drag
            end
          end

          private

          def total_distance(state)
            dx = state.position.x - @starting_position.x
            dy = state.position.y - @starting_position.y
            dz = state.position.z - @starting_position.z
            Math.sqrt(dx**2 + dy**2 + dz**2)
          end
        end
      end
    end
  end
end
