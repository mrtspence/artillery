# frozen_string_literal: true

module Artillery
  module Mechanisms
    # Encapsulates the state flowing through the mechanism resolution pipeline
    # Maintains both player input and accumulated transformations
    class PipelineContext
      attr_reader :player_input, :transforms

      # @param player_input [Hash] Raw player input (e.g., { powder_charges: 3, angle_deg: 45 })
      def initialize(player_input = {})
        @player_input = player_input.dup
        @transforms = {}  # Hash of key => current_value after all transforms
      end

      # Apply a transform to this context
      # If the key already exists, applies the transform's operation to the current value
      # If the key doesn't exist:
      #   - For additive operations: sets the value
      #   - For multiplicative operations: sets to 0 (so subsequent transforms can affect it)
      #
      # @param transform [PipelineTransform] The transformation to apply
      # @return [self] For method chaining
      def set_or_update(transform)
        unless transform.is_a?(PipelineTransform)
          raise ArgumentError, "Expected PipelineTransform, got #{transform.class}"
        end

        current_value = @transforms[transform.key]

        # If key doesn't exist and operation is multiplicative, initialize to 0
        if current_value.nil? && transform.multiplicative?
          @transforms[transform.key] = 0
          return self
        end

        # Apply the transform
        @transforms[transform.key] = transform.apply(current_value)
        self
      end

      # Get a value from the context
      # Checks transforms first, then falls back to player_input
      #
      # @param key [Symbol] The key to retrieve
      # @return [Object, nil] The value, or nil if not found
      def get(key)
        @transforms.fetch(key) { @player_input[key] }
      end

      # Alias for hash-like access
      def [](key)
        get(key)
      end

      # Check if a key exists in either transforms or player_input
      # @param key [Symbol] The key to check
      # @return [Boolean]
      def has?(key)
        @transforms.key?(key) || @player_input.key?(key)
      end

      # Check if a key exists in transforms (not just player_input)
      # @param key [Symbol] The key to check
      # @return [Boolean]
      def transformed?(key)
        @transforms.key?(key)
      end

      # Convert context to Ballistic3D engine inputs
      # Maps intermediate keys (like base_initial_velocity) to engine keys (initial_velocity)
      #
      # @return [Hash] Ballistic engine parameters
      def to_ballistic_inputs
        {
          angle_deg: get(:angle_deg) || 45.0,
          initial_velocity: get(:initial_velocity) || get(:base_initial_velocity) || 500.0,
          shell_weight: get(:shell_weight) || 25.0,
          deflection_deg: get(:deflection_deg) || 0.0,
          area_of_effect: get(:area_of_effect) || 0.0,
          surface_area: get(:surface_area) || 0.05
        }
      end

      # Get all resolved attributes as a hash (for backwards compatibility)
      # @return [Hash] Combined player_input and transforms
      def to_h
        player_input.merge(@transforms)
      end

      # Freeze this context to prevent further modifications
      # @return [self]
      def freeze!
        @player_input.freeze
        @transforms.freeze
        freeze
      end

      def inspect
        "#<PipelineContext player_input=#{@player_input.inspect} transforms=#{@transforms.keys.inspect}>"
      end
    end
  end
end
