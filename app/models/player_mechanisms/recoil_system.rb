# frozen_string_literal: true

module PlayerMechanisms
  # Recoil System - Absorbs firing forces
  # Affects turn order (recovery time) and slight accuracy penalty if poor
  class RecoilSystem < PlayerMechanism
    # Default modifiers structure:
    # {
    #   recoil_type: "basic_spring" | "hydropneumatic" | "soft_recoil"
    #   recovery_time_base: 2.0,       # Seconds to recover from recoil
    #   accuracy_penalty: 0.3          # Degrees of additional variance
    # }

    def runtime_class
      Artillery::Mechanisms::Runtimes::RecoilSystemRuntime
    end

    def input_keys
      []  # Recoil system doesn't consume player input
    end

    def output_keys
      []  # Affects turn_order_delay and potentially angle_deg variance
    end
  end
end
