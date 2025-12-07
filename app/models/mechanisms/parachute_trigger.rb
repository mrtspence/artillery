# frozen_string_literal: true

# THIS IS A SKETCH TODO: GET THIS ACTUALLY WORKING

class ParachuteTrigger < Mechanism
  def simulate(input)
    {
      hook: Artillery::Engines::Hooks::Flight::ParachuteDeploy.new(
        deploy_altitude: upgrades[:deploy_below],
        deploy_after_time: upgrades[:delay_secs]
      )
    }
  end
end
