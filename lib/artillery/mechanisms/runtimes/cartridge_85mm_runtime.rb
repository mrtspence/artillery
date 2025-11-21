# frozen_string_literal: true

module Artillery
  module Mechanisms
    module Runtimes
      class Cartridge85mmRuntime < RuntimeBase
        attr_reader :velocity_variance, :weight_variance

        def initialize_runtime
          rng = Random.new(random_seed + mechanism.id)

          # Randomize manufacturing variance (±5% velocity, ±2% weight)
          @velocity_variance = 0.95 + rng.rand * 0.1
          @weight_variance = 0.98 + rng.rand * 0.04
        end

        def resolve(context)
          # Don't validate inputs - powder_charges is optional with default
          powder_charges = context[:powder_charges] || 1

          # Calculate velocity based on charges
          base_v = mechanism.modifiers['base_velocity'] || 400
          charge_increment = mechanism.modifiers['charge_velocity_per_unit'] || 50

          velocity = (base_v + powder_charges * charge_increment) * velocity_variance

          # Apply weight variance
          weight = (mechanism.modifiers['shell_weight_kg'] || 8.4) * weight_variance

          # Calculate surface area from caliber (assuming spherical projectile)
          caliber_m = (mechanism.modifiers['caliber_mm'] || 84.5) / 1000.0
          area = Math::PI * (caliber_m / 2) ** 2

          {
            base_initial_velocity: velocity,
            shell_weight: weight,
            surface_area: area,
            caliber_mm: mechanism.modifiers['caliber_mm'] || 84.5
          }
        end

        def metadata
          {
            slot: :cartridge,
            control_type: :slider,
            input_key: :powder_charges,
            label: "Powder Charges",
            min: 1,
            max: 5,
            step: 1,
            default: 2,
            unit: "charges"
          }
        end
      end
    end
  end
end

# Alias for easier access
module PlayerMechanisms
  Cartridge85mmRuntime = Artillery::Mechanisms::Runtimes::Cartridge85mmRuntime
end
