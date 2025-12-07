# frozen_string_literal: true

module Artillery
  module Platforms
    # Ordnance QF 18-pounder field gun
    # British field artillery piece from the early 20th century
    # Quick-firing breech, accurate deflection control, reliable recoil system
    class Qf18Pounder < Base
      class << self
        def key
          "qf_18_pounder"
        end

        def name
          "Ordnance QF 18-pounder"
        end

        def description
          "British field gun of the early 20th century. Quick-firing breech, "\
          "accurate deflection control, and reliable recoil system. "\
          "Edwardian-era technology."
        end

        def slot_requirements
          @slot_requirements ||= [
            # Aiming mechanisms (required)
            SlotRequirement.new(
              slot_key: :elevation,
              required: true,
              allowed_types: ["PlayerMechanisms::ElevationDial"],
              description: "Vertical aiming mechanism (dial or quadrant)"
            ),

            SlotRequirement.new(
              slot_key: :deflection,
              required: true,
              allowed_types: ["PlayerMechanisms::DeflectionScrew"],
              description: "Horizontal aiming mechanism (screw or wheel)"
            ),

            # Core ballistic components (required)
            SlotRequirement.new(
              slot_key: :cartridge,
              required: true,
              allowed_types: ["PlayerMechanisms::Cartridge85mm"],
              description: "Ammunition type - must be 85mm caliber"
            ),

            SlotRequirement.new(
              slot_key: :barrel,
              required: true,
              allowed_types: ["PlayerMechanisms::Barrel85mm"],
              description: "Gun barrel - must be 85mm caliber"
            ),

            # Mechanical systems (required)
            SlotRequirement.new(
              slot_key: :breech,
              required: true,
              allowed_types: ["PlayerMechanisms::BreechQf"],
              description: "Quick-firing breech mechanism"
            ),

            SlotRequirement.new(
              slot_key: :recoil_system,
              required: true,
              allowed_types: ["PlayerMechanisms::RecoilSystem"],
              description: "Hydro-pneumatic or spring recoil system"
            ),

            # Sighting (required for this platform)
            SlotRequirement.new(
              slot_key: :sight,
              required: true,
              allowed_types: ["PlayerMechanisms::OpticalSight"],
              description: "Telescopic or iron sights"
            )
          ]
        end

        def ui_characteristics
          {
            era: "Edwardian",
            country: "United Kingdom",
            role: "Field Artillery",
            crew_size: 5,
            rate_of_fire: "20 rounds/min (theoretical)",
            max_range_meters: 6525,
            shell_weight_kg_range: [8.1, 8.5],
            muzzle_velocity_range: [492, 502], # m/s
            weight_kg: 1282 # Gun + carriage
          }
        end
      end
    end

    # Register platform in registry
    Registry.register(:qf_18_pounder, Qf18Pounder)
  end
end
