# frozen_string_literal: true

module Artillery
  module Mechanisms
    # Represents a single transformation to apply in the mechanism pipeline
    # Encapsulates a key, value, and operation (increment, multiply, set)
    class PipelineTransform
      VALID_OPERATIONS = %i[set increment multiply].freeze

      attr_reader :key, :value, :operation

      # @param key [Symbol] The attribute key to transform
      # @param value [Numeric, Object] The value to apply
      # @param operation [Symbol] The operation to perform (:set, :increment, :multiply)
      def initialize(key:, value:, operation:)
        @key = key
        @value = value
        @operation = operation

        validate!
      end

      # Apply this transform to an existing value
      # @param current_value [Numeric, nil] The current value (nil if not set)
      # @return [Numeric, Object] The transformed value
      def apply(current_value)
        case operation
        when :set
          value
        when :increment
          (current_value || 0) + value
        when :multiply
          # If no current value, set to 0 so subsequent transforms can affect it
          return 0 if current_value.nil?
          current_value * value
        else
          raise ArgumentError, "Unknown operation: #{operation}"
        end
      end

      # Check if this transform is multiplicative (needs existing value)
      # @return [Boolean]
      def multiplicative?
        operation == :multiply
      end

      # Check if this transform is additive (can work without existing value)
      # @return [Boolean]
      def additive?
        %i[set increment].include?(operation)
      end

      def to_s
        "PipelineTransform(#{key}: #{operation} #{value})"
      end

      def inspect
        to_s
      end

      private

      def validate!
        unless VALID_OPERATIONS.include?(operation)
          raise ArgumentError, "Invalid operation: #{operation}. Must be one of #{VALID_OPERATIONS.join(', ')}"
        end

        unless key.is_a?(Symbol)
          raise ArgumentError, "Key must be a Symbol, got #{key.class}"
        end
      end
    end
  end
end
