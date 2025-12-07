# frozen_string_literal: true

module Artillery
  module Mechanisms
    module Runtimes
      class Barrel85mmRuntime < RuntimeBase
        attr_reader :velocity_multiplier, :accuracy_variance

        def initialize_runtime
          validate_required_modifiers!(['construction', 'length_meters', 'wear_factor'])

          rng = Random.new(random_seed + mechanism.id)

          # Base velocity multiplier from barrel variant
          base_multiplier = case mechanism.modifiers['construction']
          when 'chrome_lined' then 1.05  # Better rifling
          when 'lightweight' then 0.95   # Shorter/lighter barrel
          else 1.0                        # Standard steel
          end

          # Apply wear factor randomization (±5%)
          wear = mechanism.modifiers['wear_factor'] || 1.0
          @velocity_multiplier = base_multiplier * wear * (0.95 + rng.rand * 0.1)

          # Accuracy variance in degrees
          base_variance = case mechanism.modifiers['construction']
          when 'chrome_lined' then 0.5   # Very accurate
          when 'lightweight' then 1.5    # Less stable
          else 1.0                        # Standard
          end

          # Upgrades reduce variance
          upgrade_reduction = mechanism.upgrade_level * 0.1
          @accuracy_variance = base_variance * (1.0 - upgrade_reduction) * (0.9 + rng.rand * 0.2)
        end

        def resolve(context)
          # Barrel multiplies velocity and can add accuracy offset
          # We multiply base_initial_velocity if it exists, otherwise do nothing
          transforms = []

          if context.has?(:base_initial_velocity)
            transforms << transform(
              key: :base_initial_velocity,
              value: velocity_multiplier,
              operation: :multiply
            )
          end

          # Add random accuracy offset within variance (can be + or -)
          # This affects angle_deg if present
          if context.has?(:angle_deg)
            rng = Random.new(random_seed + mechanism.id + context.get(:angle_deg).to_i)
            offset = (rng.rand - 0.5) * accuracy_variance * 2

            transforms << transform(
              key: :angle_deg,
              value: offset,
              operation: :increment
            )
          end

          transforms
        end

        def metadata
          {
            slot: :barrel,
            control_type: :info_display,
            label: "Barrel (#{mechanism.modifiers['construction']})",
            info: {
              length: "#{mechanism.modifiers['length_meters']}m",
              velocity_mult: "×#{velocity_multiplier.round(3)}",
              accuracy: "±#{accuracy_variance.round(2)}°"
            }
          }
        end
      end
    end
  end
end

# Alias for easier access
module PlayerMechanisms
  Barrel85mmRuntime = Artillery::Mechanisms::Runtimes::Barrel85mmRuntime
end
