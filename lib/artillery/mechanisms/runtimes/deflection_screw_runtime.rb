# frozen_string_literal: true

module Artillery
  module Mechanisms
    module Runtimes
      class DeflectionScrewRuntime < RuntimeBase
        attr_reader :degrees_per_turn_runtime

        def initialize_runtime
          validate_required_modifiers!(['degrees_per_turn', 'max_deflection', 'thread_pitch'])

          rng = Random.new(random_seed + mechanism.id)

          # Base degrees per turn based on thread pitch
          base_degrees = case mechanism.modifiers['thread_pitch']
          when 'fine' then 0.25     # Very precise
          when 'coarse' then 1.0    # Faster adjustment
          else 0.5                  # Standard
          end

          # Upgrades improve precision
          upgrade_bonus = mechanism.upgrade_level * 0.05

          # Randomize screw calibration slightly (±5%)
          @degrees_per_turn_runtime = base_degrees * (1.0 - upgrade_bonus) * (0.95 + rng.rand * 0.1)
        end

        def resolve(context)
          # Convert player's screw turns to degrees
          turns = context.get(:deflection) || 0
          deflection = turns * degrees_per_turn_runtime

          # Clamp to max deflection
          max_def = mechanism.modifiers['max_deflection'] || 8
          deflection = [[deflection, max_def].min, -max_def].max

          [
            transform(key: :deflection_deg, value: deflection, operation: :set)
          ]
        end

        def metadata
          max_turns = ((mechanism.modifiers['max_deflection'] || 8) / degrees_per_turn_runtime).to_i

          {
            slot: :deflection,
            control_type: :slider,
            input_key: :deflection,
            label: "Deflection Screw",
            min: -max_turns,
            max: max_turns,
            step: 1,
            default: 0,
            unit: "turns",
            conversion: "#{degrees_per_turn_runtime.round(3)}° per turn"
          }
        end
      end
    end
  end
end

# Alias for easier access
module PlayerMechanisms
  DeflectionScrewRuntime = Artillery::Mechanisms::Runtimes::DeflectionScrewRuntime
end
