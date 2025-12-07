# frozen_string_literal: true

module Artillery
  module Engines
    module Inputs
      class Ballistic3D
        attr_reader :angle_deg, :initial_velocity, :shell_weight,
                    :deflection_deg, :area_of_effect, :surface_area, :initial_height

        def initialize(angle_deg:, initial_velocity:, shell_weight:, deflection_deg: 0, area_of_effect: 0, surface_area: 0, initial_height: 1.0)
          @angle_deg = angle_deg
          @initial_velocity = initial_velocity
          @shell_weight = shell_weight
          @deflection_deg = deflection_deg
          @area_of_effect = area_of_effect
          @surface_area = surface_area
          @initial_height = initial_height
        end

        def self.from_resolver(resolver)
          raise ArgumentError, 'Missing angle_deg' unless resolver[:angle_deg]
          raise ArgumentError, 'Missing initial_velocity' unless resolver[:initial_velocity]
          raise ArgumentError, 'Missing shell_weight' unless resolver[:shell_weight]

          new(
            angle_deg: resolver[:angle_deg],
            initial_velocity: resolver[:initial_velocity],
            shell_weight: resolver[:shell_weight],
            deflection_deg: resolver[:deflection_deg] || 0,
            area_of_effect: resolver[:area_of_effect] || 0,
            surface_area: resolver[:surface_area] || 0,
            initial_height: resolver[:initial_height] || 1.0
          )
        end

        def to_h
          {
            angle_deg:,
            initial_velocity:,
            shell_weight:,
            deflection_deg:,
            area_of_effect:,
            surface_area:,
            initial_height:
          }
        end
      end
    end
  end
end
