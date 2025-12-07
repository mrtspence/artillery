# frozen_string_literal: true

module PlayerMechanisms
  # QF 18-Pounder Quick-Firing Breech
  # Affects loading time and turn order
  class BreechQf < PlayerMechanism
    # Default modifiers structure:
    # {
    #   breech_type: "screw" | "sliding_block" | "interrupted_screw"
    #   base_loading_time: 3.0                  # Seconds to reload
    # }

    def runtime_class
      Artillery::Mechanisms::Runtimes::BreechQfRuntime
    end

    def input_keys
      []  # Breech doesn't consume player input
    end

    def output_keys
      []  # Doesn't produce ballistic outputs, only affects turn_order_delay
    end
  end
end
