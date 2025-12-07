# frozen_string_literal: true

module Artillery
  module Mechanisms
    class PipelineResolver
      attr_reader :runtimes, :player_input, :orderer

      def initialize(runtimes, player_input)
        @runtimes = runtimes
        @player_input = player_input
        @orderer = MechanismOrderer.new(runtimes)
      end

      # Execute the pipeline and return resolved context
      # @return [PipelineContext] Complete resolved context
      def resolve
        context = PipelineContext.new(player_input)

        # Delegate ordering to MechanismOrderer
        orderer.ordered.each do |runtime|
          transforms = runtime.resolve(context)

          # Apply each transform to the context
          Array(transforms).each do |transform|
            context.set_or_update(transform)
          end
        end

        context
      end

      # Extract only ballistic engine inputs
      # @return [Artillery::Engines::Inputs::Ballistic3D] Ballistic engine parameters
      def ballistic_attributes
        context = resolve
        context.to_ballistic_inputs
      end

      # Calculate total turn order delay
      # @return [Float] Total delay in seconds
      def turn_order_delay
        runtimes.sum(&:turn_order_delay)
      end

      # Collect all UI metadata from runtimes
      # @return [Array<Hash>] UI metadata for each mechanism
      def ui_metadata
        runtimes.map { |r| r.metadata }.reject(&:empty?)
      end

      # Collect all assistance data
      # @param context [Hash] Optional pre-resolved context
      # @return [Hash] Combined assistance data
      def assistance_data(context = nil)
        context ||= resolve

        runtimes
          .select { |r| r.respond_to?(:assistance_data) }
          .map { |r| r.assistance_data(context) }
          .reduce({}, :merge)
      end

      # Collect all engine affectors
      # @return [Array<Affector>] Combined affectors
      def engine_affectors
        runtimes.flat_map(&:affectors)
      end

      # Collect all engine hooks
      # @return [Array<Hook>] Combined hooks
      def engine_hooks
        runtimes.flat_map(&:hooks)
      end
    end
  end
end
