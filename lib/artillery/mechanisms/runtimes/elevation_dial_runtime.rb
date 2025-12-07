# frozen_string_literal: true

module Artillery
  module Mechanisms
    module Runtimes
      class ElevationDialRuntime < RuntimeBase
        attr_reader :degrees_per_click_runtime

        def initialize_runtime
          validate_required_modifiers!(['graduations', 'degrees_per_click', 'max_elevation', 'min_elevation'])

          rng = Random.new(random_seed + mechanism.id)

          # Base degrees per click based on graduations
          base_degrees = case mechanism.modifiers['graduations']
          when 'fine' then 0.5        # Very precise
          when 'vernier' then 0.1     # Extremely precise
          when 'coarse' then 2.0      # Rough adjustment
          else 1.0                    # Standard
          end

          # Upgrades improve precision
          upgrade_bonus = mechanism.upgrade_level * 0.05

          # Randomize dial calibration slightly (±4%)
          @degrees_per_click_runtime = base_degrees * (1.0 - upgrade_bonus) * (0.96 + rng.rand * 0.08)
        end

        def resolve(context)
          # Convert player's clicks to degrees
          clicks = context.get(:elevation) || 0
          angle = clicks * degrees_per_click_runtime

          # Clamp to min/max elevation
          min_elev = mechanism.modifiers['min_elevation'] || 5
          max_elev = mechanism.modifiers['max_elevation'] || 45
          angle = [[angle, max_elev].min, min_elev].max

          [
            transform(key: :angle_deg, value: angle, operation: :set)
          ]
        end

        def metadata
          min_clicks = ((mechanism.modifiers['min_elevation'] || 5) / degrees_per_click_runtime).ceil
          max_clicks = ((mechanism.modifiers['max_elevation'] || 45) / degrees_per_click_runtime).floor

          {
            slot: :elevation,
            control_type: :dial,
            input_key: :elevation,
            label: "Elevation Dial",
            min: min_clicks,
            max: max_clicks,
            step: 1,
            default: (min_clicks + max_clicks) / 2,
            unit: "clicks",
            conversion: "#{degrees_per_click_runtime.round(3)}° per click"
          }
        end
      end
    end
  end
end

# Alias for easier access
module PlayerMechanisms
  ElevationDialRuntime = Artillery::Mechanisms::Runtimes::ElevationDialRuntime
end
