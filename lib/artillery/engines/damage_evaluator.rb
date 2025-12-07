# frozen_string_literal: true

module Artillery
  module Engines
    # DamageEvaluator is a simple, stateless engine that takes in results from
    # the TargetResolutionEngine and translates them into abstract scoring or
    # game-side consequences.
    #
    # It is designed to be easily extensible — by game mode, user loadout,
    # kill types, multipliers, or point-based objectives.
    #
    # Input: Array of { target:, result:, distance: }
    # Output: Array of { target_id:, result:, score: }
    #
    # Does not mutate world state or DOM/Net; it is pure and replay-safe.
    class DamageEvaluator
      def initialize(resolution_results)
        @results = resolution_results
      end

      def call
        @results.map do |r|
          {
            target_id: r[:target].id,
            result: r[:result],
            score: compute_score(r[:target], r[:result], r[:distance])
          }
        end
      end

      private

      def compute_score(target, result, distance)
        base = {
          destroyed: 100,
          damaged: 50,
          dented: 25,
          resistant: 0,
          missed: 0,
          unknown: 0
        }[result] || 0

        # Example: reduce score by distance factor if needed
        (base - (distance.to_f * 2)).clamp(0, base)
      end
    end
  end
end
