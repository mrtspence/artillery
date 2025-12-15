# frozen_string_literal: true

module PlayerMechanisms
  module Edwardian
    # QF 18-Pounder 85mm Barrel
    # Affects muzzle velocity and accuracy through length and construction
    class Barrel85mm < PlayerMechanism
      # Default modifiers structure:
      # {
      #   length_meters: 2.5,                    # Barrel length
      #   construction: "steel" | "chrome_lined" # Material affects accuracy
      #   wear_factor: 0.95-1.05                 # Manufacturing variance (randomized per match)
      #   velocity_multiplier: 1.0               # Base velocity scaling
      # }

      def runtime_class
        Artillery::Mechanisms::Runtimes::Barrel85mmRuntime
      end

      def input_keys
        []  # Barrel doesn't consume player input
      end

      def output_keys
        [:initial_velocity_multiplier, :accuracy_variance_degrees]
      end
    end
  end
end
