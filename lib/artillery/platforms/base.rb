# frozen_string_literal: true

module Artillery
  module Platforms
    # Base class for all artillery platform definitions
    # Platforms define constraints and requirements for valid loadouts
    class Base
      class << self
        # Platform metadata

        # Unique identifier for this platform
        # @return [String]
        def key
          raise NotImplementedError, "#{name} must implement .key"
        end

        # Display name for this platform
        # @return [String]
        def name
          raise NotImplementedError, "#{name} must implement .name"
        end

        # Platform description
        # @return [String]
        def description
          raise NotImplementedError, "#{name} must implement .description"
        end

        # Engine type this platform uses
        # @return [String]
        def engine_type
          "ballistic_3d"  # Default, can override
        end

        # Slot requirements for this platform
        # @return [Array<SlotRequirement>] Array of slot requirements
        def slot_requirements
          raise NotImplementedError, "#{name} must implement .slot_requirements"
        end

        # Get slot requirement by key
        # @param slot_key [Symbol, String] The slot key
        # @return [SlotRequirement, nil] The slot requirement or nil if not found
        def slot_requirement_for(slot_key)
          slot_requirements.find { |req| req.slot_key == slot_key.to_sym }
        end

        # Get all required slot keys
        # @return [Array<Symbol>] Array of required slot keys
        def required_slot_keys
          slot_requirements.select(&:required?).map(&:slot_key)
        end

        # Get all defined slot keys
        # @return [Array<Symbol>] Array of all slot keys
        def defined_slot_keys
          slot_requirements.map(&:slot_key)
        end

        # Check if a mechanism is allowed in a specific slot
        # @param slot_key [Symbol, String] The slot being filled
        # @param mechanism [PlayerMechanism] The mechanism to validate
        # @return [Boolean]
        def mechanism_allowed_in_slot?(slot_key, mechanism)
          requirement = slot_requirement_for(slot_key)
          return false unless requirement

          requirement.allows?(mechanism)
        end

        # Validate a loadout against platform requirements
        # @param loadout [PlayerLoadout] The loadout to validate
        # @return [Array<String>] Array of error messages (empty if valid)
        def validate_loadout(loadout)
          @errors = []

          # Guard: check platform type matches
          validate_platform_type(loadout)
          return @errors if @errors.any?

          # Validate required slots are filled and have correct mechanism types
          validate_required_slots(loadout)

          # Check for undefined extra slots
          validate_no_extra_slots(loadout)

          # Add platform-specific constraints
          validate_additional_constraints(loadout)

          @errors
        end

        # Platform characteristics for UI/display
        # @return [Hash]
        def ui_characteristics
          {}  # Override in subclasses
        end

        private

        attr_reader :errors

        # Validate loadout has correct platform_type
        # @param loadout [PlayerLoadout]
        def validate_platform_type(loadout)
          return if loadout.platform_type == key

          @errors << "Loadout platform_type must be '#{key}'"
        end

        # Validate all required slots are filled with allowed mechanisms
        # @param loadout [PlayerLoadout]
        def validate_required_slots(loadout)
          slot_requirements.each do |requirement|
            next unless requirement.required?

            mechanism = loadout.player_mechanisms.find { |m| m.slot_key == requirement.slot_key.to_s }

            if mechanism.nil?
              @errors << "Required slot '#{requirement.slot_key}' is not filled"
            else
              validate_mechanism_type_for_slot(requirement, mechanism)
            end
          end
        end

        # Validate mechanism type is allowed in slot
        # @param requirement [SlotRequirement]
        # @param mechanism [PlayerMechanism]
        def validate_mechanism_type_for_slot(requirement, mechanism)
          return if requirement.allows?(mechanism)

          @errors << "Mechanism #{mechanism.class.name} is not allowed in slot '#{requirement.slot_key}'"
        end

        # Validate loadout doesn't have undefined slots
        # @param loadout [PlayerLoadout]
        def validate_no_extra_slots(loadout)
          defined_slots = defined_slot_keys.map(&:to_s)
          loadout_slots = loadout.player_mechanisms.map(&:slot_key).uniq
          extra_slots = loadout_slots - defined_slots

          return if extra_slots.empty?

          @errors << "Loadout contains undefined slots: #{extra_slots.join(', ')}"
        end

        # Additional platform-specific constraints
        # Override in subclasses for custom validation
        # @param loadout [PlayerLoadout]
        def validate_additional_constraints(loadout)
          # Override in subclasses to add errors to @errors
        end
      end
    end
  end
end
