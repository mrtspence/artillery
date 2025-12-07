# frozen_string_literal: true

module PlayerMechanisms
  # Deflection Screw - Horizontal aim adjustment via screw mechanism
  # Used on QF 18-pounder for traverse control
  class DeflectionScrew < PlayerMechanism
    # Default modifiers structure:
    # {
    #   degrees_per_turn: 0.5,     # Precision of screw adjustment
    #   max_deflection: 8,          # Maximum horizontal angle (QF 18-pdr: ~8°)
    #   thread_pitch: "fine" | "coarse"
    # }

    def runtime_class
      Artillery::Mechanisms::Runtimes::DeflectionScrewRuntime
    end

    def input_keys
      [:deflection]  # Player input: screw turns (can be negative for left)
    end

    def output_keys
      [:deflection_deg]
    end
  end
end
