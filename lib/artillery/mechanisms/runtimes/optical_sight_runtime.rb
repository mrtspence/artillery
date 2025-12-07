# frozen_string_literal: true

module Artillery
  module Mechanisms
    module Runtimes
      class OpticalSightRuntime < RuntimeBase
        attr_reader :estimate_accuracy, :magnification

        def initialize_runtime
          validate_required_modifiers!(['sight_type', 'magnification'])

          rng = Random.new(random_seed + mechanism.id)

          # Base accuracy by sight type
          base_accuracy = case mechanism.modifiers['sight_type']
          when 'range_finder' then 0.9   # Most accurate
          when 'telescopic' then 0.75    # Good
          when 'iron' then 0.5          # Basic
          else 0.6                       # Standard
          end

          # Upgrades improve accuracy
          upgrade_bonus = mechanism.upgrade_level * 0.05

          # Randomize slightly (±5%)
          @estimate_accuracy = [base_accuracy + upgrade_bonus, 1.0].min * (0.95 + rng.rand * 0.1)

          @magnification = mechanism.modifiers['magnification'] || 1.0
        end

        def resolve(context)
          # Sight doesn't produce transforms
          []
        end

        def assistance_data(context)
          # Provide distance estimate to target
          # In a real match, this would use match.target_distance
          # For now, simulate with placeholder
          true_distance = 500  # Would come from match context

          # Add error based on accuracy
          rng = Random.new(random_seed + mechanism.id)
          error_margin = true_distance * (1.0 - estimate_accuracy) * 0.3
          estimated_distance = true_distance + (rng.rand - 0.5) * error_margin * 2

          {
            estimated_target_distance: estimated_distance.round(1),
            sight_magnification: magnification,
            confidence: estimate_accuracy
          }
        end

        def metadata
          {
            slot: :sight,
            control_type: :info_display,
            label: "Sight (#{mechanism.modifiers['sight_type'] || 'standard'})",
            info: {
              type: mechanism.modifiers['sight_type'] || 'standard',
              magnification: "×#{magnification}",
              accuracy: "#{(estimate_accuracy * 100).round(0)}%"
            }
          }
        end
      end
    end
  end
end

# Alias for easier access
module PlayerMechanisms
  OpticalSightRuntime = Artillery::Mechanisms::Runtimes::OpticalSightRuntime
end
