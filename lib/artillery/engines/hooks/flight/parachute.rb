
module Artillery
  module Engines
    module Hooks
      module Flight
        class ParachuteDeploy < FlightHook
          def initialize(deploy_altitude:)
            @deploy_altitude = deploy_altitude
            @deployed = false
          end

          def call!(state)
            return if @deployed
            if state.position[2] <= @deploy_altitude
              @deployed = true
              state.velocity *= 0.3 # reduce all components
            end
          end
        end
      end
    end
  end
end
