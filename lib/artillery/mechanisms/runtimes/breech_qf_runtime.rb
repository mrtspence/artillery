# frozen_string_literal: true

module Artillery
  module Mechanisms
    module Runtimes
      class BreechQfRuntime < RuntimeBase
        attr_reader :loading_time

        def initialize_runtime
          validate_required_modifiers!(['breech_type', 'base_loading_time'])

          rng = Random.new(random_seed + mechanism.id)

          # Base loading time by breech type
          base_time = case mechanism.modifiers['breech_type']
          when 'sliding_block' then 2.5      # Fastest
          when 'interrupted_screw' then 3.0  # Standard QF
          when 'screw' then 4.0              # Slower
          else 3.0
          end

          # Upgrades reduce loading time
          upgrade_reduction = mechanism.upgrade_level * 0.2

          # Apply randomization (±10%)
          @loading_time = base_time * (1.0 - upgrade_reduction) * (0.9 + rng.rand * 0.2)
        end

        def resolve(context)
          # Breech doesn't produce transforms, only affects turn_order_delay
          []
        end

        def turn_order_delay
          loading_time
        end

        def metadata
          {
            slot: :breech,
            control_type: :info_display,
            label: "Breech (#{mechanism.modifiers['breech_type'] || 'interrupted_screw'})",
            info: {
              loading_time: "#{loading_time.round(2)}s",
              type: mechanism.modifiers['breech_type'] || 'interrupted_screw'
            }
          }
        end
      end
    end
  end
end

# Alias for easier access
module PlayerMechanisms
  BreechQfRuntime = Artillery::Mechanisms::Runtimes::BreechQfRuntime
end
