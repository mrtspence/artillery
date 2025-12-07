# frozen_string_literal: true

module Artillery
  module Mechanisms
    class RuntimeBase
      attr_reader :mechanism, :match, :random_seed

      def initialize(mechanism:, match:, random_seed:)
        @mechanism = mechanism
        @match = match
        @random_seed = random_seed
        initialize_runtime
      end

      # Override to set up randomized state
      # Called automatically during initialization
      def initialize_runtime
        # Subclasses implement this
      end

      # Main pipeline method: receives context, returns array of transforms
      # @param context [PipelineContext] Accumulated state from previous pipeline stages
      # @return [Array<PipelineTransform>] Transformations to apply to context
      def resolve(context)
        raise NotImplementedError, "#{self.class.name} must implement #resolve"
      end

      # Optional: validate that required inputs are present
      # @param context [PipelineContext] Current pipeline context
      # @raise [ArgumentError] if required inputs missing
      def validate_inputs!(context)
        mechanism.input_keys.each do |key|
          unless context.has?(key)
            raise ArgumentError, "Missing required input: #{key} for #{mechanism.class.name}"
          end
        end
      end

      # Validate that required modifiers are present
      # @param required_keys [Array<String>] List of required modifier keys
      # @raise [ArgumentError] if any required modifiers are missing
      def validate_required_modifiers!(required_keys)
        missing_keys = required_keys.reject { |key| mechanism.modifiers.key?(key) }

        if missing_keys.any?
          raise ArgumentError, "#{mechanism.class.name} is missing required modifiers: #{missing_keys.join(', ')}"
        end
      end

      # Helper to create a transform
      # @param key [Symbol] The attribute key
      # @param value [Numeric] The value to apply
      # @param operation [Symbol] The operation (:set, :add, :multiply, etc.)
      # @return [PipelineTransform]
      def transform(key:, value:, operation: :set)
        PipelineTransform.new(key: key, value: value, operation: operation)
      end

      # Optional: provide metadata for UI rendering
      # @return [Hash] Metadata for ViewComponents
      def metadata
        {}
      end

      # Optional: provide turn-order effects
      # @return [Float] Time delay in seconds
      def turn_order_delay
        0.0
      end

      # Optional: provide engine affectors
      # @return [Array<Affector>] Affectors to add to engine
      def affectors
        []
      end

      # Optional: provide engine hooks
      # @return [Array<Hook>] Hooks to add to engine
      def hooks
        []
      end
    end
  end
end
