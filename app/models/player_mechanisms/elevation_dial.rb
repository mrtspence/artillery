# frozen_string_literal: true

module PlayerMechanisms
  # Elevation Dial - Vertical aim adjustment
  # Converts player's elevation clicks to angle degrees
  class ElevationDial < PlayerMechanism
    # Default modifiers structure:
    # {
    #   graduations: "coarse" | "fine" | "vernier"
    #   degrees_per_click: 2.0,    # Angle change per click
    #   max_elevation: 45,          # Maximum elevation angle
    #   min_elevation: 5            # Minimum elevation angle
    # }

    def runtime_class
      Artillery::Mechanisms::Runtimes::ElevationDialRuntime
    end

    def input_keys
      [:elevation]  # Player input: dial clicks
    end

    def output_keys
      [:angle_deg]
    end
  end
end
