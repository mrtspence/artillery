# frozen_string_literal: true

module Artillery
  module Mechanisms
    module Runtimes
      class RecoilSystemRuntime < RuntimeBase
        attr_reader :recovery_time, :accuracy_penalty

        def initialize_runtime
          validate_required_modifiers!(['recoil_type', 'recovery_time_base', 'accuracy_penalty'])

          rng = Random.new(random_seed + mechanism.id)

          # Base recovery time by recoil type
          base_time = case mechanism.modifiers['recoil_type']
          when 'soft_recoil' then 1.0        # Fastest (pre-recoil system)
          when 'hydropneumatic' then 1.5     # Modern, efficient
          when 'basic_spring' then 2.5       # Simple, slower
          else 2.0                            # Standard
          end

          # Upgrades reduce recovery time
          upgrade_reduction = mechanism.upgrade_level * 0.15

          # Apply randomization (±10%)
          @recovery_time = base_time * (1.0 - upgrade_reduction) * (0.9 + rng.rand * 0.2)

          # Accuracy penalty based on recoil type
          base_penalty = case mechanism.modifiers['recoil_type']
          when 'soft_recoil' then 0.1
          when 'hydropneumatic' then 0.2
          when 'basic_spring' then 0.5
          else 0.3
          end

          # Upgrades reduce penalty
          @accuracy_penalty = base_penalty * (1.0 - upgrade_reduction)
        end

        def resolve(context)
          # Add slight random accuracy penalty if angle is being set
          return [] unless context.has?(:angle_deg)

          # Apply random accuracy offset within penalty range
          rng = Random.new(random_seed + mechanism.id + (context.get(:angle_deg) * 100).to_i)
          offset = (rng.rand - 0.5) * accuracy_penalty * 2

          [
            transform(key: :angle_deg, value: offset, operation: :increment)
          ]
        end

        def turn_order_delay
          recovery_time
        end

        def metadata
          {
            slot: :recoil_system,
            control_type: :info_display,
            label: "Recoil System (#{mechanism.modifiers['recoil_type'] || 'standard'})",
            info: {
              recovery_time: "#{recovery_time.round(2)}s",
              accuracy_penalty: "±#{accuracy_penalty.round(2)}°",
              type: mechanism.modifiers['recoil_type'] || 'standard'
            }
          }
        end
      end
    end
  end
end

# Alias for easier access
module PlayerMechanisms
  RecoilSystemRuntime = Artillery::Mechanisms::Runtimes::RecoilSystemRuntime
end
