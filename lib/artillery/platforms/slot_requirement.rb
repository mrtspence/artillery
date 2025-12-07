# frozen_string_literal: true

module Artillery
  module Platforms
    # Represents a single slot requirement for a platform
    # Encapsulates the rules for what mechanisms can fill a slot
    class SlotRequirement
      attr_reader :slot_key, :allowed_types, :description

      # @param slot_key [Symbol] The slot identifier (e.g., :barrel, :elevation)
      # @param required [Boolean] Whether this slot must be filled
      # @param allowed_types [Array<String>] Mechanism class names allowed in this slot
      # @param description [String] Human-readable description of the slot
      def initialize(slot_key:, required: true, allowed_types:, description: nil)
        @slot_key = slot_key
        @required = required
        @allowed_types = allowed_types
        @description = description
      end

      # Check if this slot is required
      # @return [Boolean]
      def required?
        @required
      end

      # Check if a mechanism is allowed in this slot
      # @param mechanism [PlayerMechanism] The mechanism to check
      # @return [Boolean]
      def allows?(mechanism)
        @allowed_types.include?(mechanism.class.name)
      end

      # Check if a mechanism class name is allowed
      # @param class_name [String] The mechanism class name
      # @return [Boolean]
      def allows_class?(class_name)
        @allowed_types.include?(class_name)
      end
    end
  end
end
