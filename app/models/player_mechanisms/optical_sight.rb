# frozen_string_literal: true

module PlayerMechanisms
  # Optical Sight - Provides aiming assistance to player
  # Doesn't affect ballistic calculations, only provides UI metadata
  class OpticalSight < PlayerMechanism
    # Default modifiers structure:
    # {
    #   sight_type: "iron" | "telescopic" | "range_finder"
    #   accuracy_bonus: 0.7,          # How accurate distance estimates are (0-1)
    #   magnification: 1.0            # Visual magnification
    # }

    def runtime_class
      Artillery::Mechanisms::Runtimes::OpticalSightRuntime
    end

    def input_keys
      []  # Sight doesn't consume player input
    end

    def output_keys
      []  # Doesn't produce ballistic outputs, only provides assistance_data
    end
  end
end
