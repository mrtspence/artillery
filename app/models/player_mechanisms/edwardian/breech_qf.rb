# frozen_string_literal: true

module PlayerMechanisms
  module Edwardian
    # Quick-Firing Breech mechanism
    # Provides rapid reload times with reduced turn order delay
    class BreechQf < PlayerMechanism
      # Default modifiers structure:
      # {
      #   mechanism_quality: "standard" | "precision"  # Build quality affects reliability
      #   lubrication: 0.9-1.1                         # Maintenance state (randomized per match)
      #   turn_order_delay: 2                          # Base reload time in turns
      # }

      def runtime_class
        Artillery::Mechanisms::Runtimes::BreechQfRuntime
      end

      def input_keys
        []  # Breech doesn't consume player input
      end

      def output_keys
        [:turn_order_delay]
      end
    end
  end
end
