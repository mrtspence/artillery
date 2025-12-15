# frozen_string_literal: true

module PlayerMechanisms
  # QF 18-Pounder 85mm Cartridge
  # Quick-firing combined shell and propellant charge
  module Edwardian
    class Cartridge85mm < PlayerMechanism
      # Default modifiers structure:
      # {
      #   shell_weight_kg: 8.4,              # Weight of projectile
      #   charge_velocity_per_unit: 50,      # m/s increase per powder charge
      #   base_velocity: 400,                # Base muzzle velocity (m/s)
      #   caliber_mm: 84.5,                  # Shell diameter
      #   construction: "steel" | "composite"  # Shell material
      #   priority: <optional>               # Custom priority (overrides column)
      # }

      def runtime_class
        Artillery::Mechanisms::Runtimes::Cartridge85mmRuntime
      end

      def input_keys
        [:powder_charges]  # Player input: number of charges (1-5)
      end

      def output_keys
        [:base_initial_velocity, :shell_weight, :surface_area, :caliber_mm]
      end

      # Allow priority to be overridden in modifiers
      def priority
        modifiers['priority'] || super
      end
    end
  end
end
