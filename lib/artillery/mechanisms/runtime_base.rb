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

      # Main pipeline method: receives context hash, returns contributions
      # @param context [Hash] Accumulated values from previous pipeline stages
      # @return [Hash] New/modified values to merge into context
      def resolve(context)
        raise NotImplementedError, "#{self.class.name} must implement #resolve"
      end

      # Optional: validate that required inputs are present
      # @param context [Hash] Current pipeline context
      # @raise [ArgumentError] if required inputs missing
      def validate_inputs!(context)
        mechanism.input_keys.each do |key|
          unless context.key?(key)
            raise ArgumentError, "Missing required input: #{key} for #{mechanism.class.name}"
          end
        end
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
