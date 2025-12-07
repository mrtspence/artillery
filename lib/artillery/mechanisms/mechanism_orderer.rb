# frozen_string_literal: true

module Artillery
  module Mechanisms
    class MechanismOrderer
      attr_reader :runtimes

      def initialize(runtimes)
        @runtimes = runtimes
      end

      # Default implementation: simple priority-based ordering
      # Uses stable sort to maintain insertion order for equal priorities
      # @return [Array<RuntimeBase>] Ordered runtimes
      def ordered
        @runtimes.sort_by.with_index { |runtime, idx| [runtime.mechanism.priority, idx] }
      end

      # Future extension point for complex ordering
      # Example: topological sort based on declared dependencies
      # @return [Array<RuntimeBase>] Dependency-ordered runtimes
      def ordered_by_dependencies
        # Build dependency graph from input_keys/output_keys
        # Perform topological sort
        # Return ordered runtimes
        raise NotImplementedError, "Topological ordering not yet implemented"
      end

      # Future: detect circular dependencies
      # @raise [StandardError] if circular dependencies detected
      def validate!
        # Check for dependency cycles
        # Raise error if detected
        raise NotImplementedError, "Dependency validation not yet implemented"
      end
    end
  end
end
