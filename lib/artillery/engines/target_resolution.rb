# frozen_string_literal: true

module Artillery
  module Engines
    # TargetResolutionEngine is responsible for evaluating spatial relationships
    # between impact data (e.g. XYZ location, trace path) and a defined set of
    # in-world targets (e.g. paper, wood, metal objects).
    #
    # This engine determines which targets are hit, missed, or partially affected
    # based on factors such as distance from explosion, material resistance, or
    # spatial overlap. It does **not** score or apply game logic.
    #
    # It is consumable by simulation, multiplayer sync, replays, and scoring engines.
    #
    # Input:
    # - impact_xyz: Array[Float, Float, Float] representing blast center
    # - trace: Array of Vectors representing shell path (optional extras)
    # - targets: Collection of target-like objects responding to `#position`, `#material`
    #
    # Output: Array of hashes: [{ target:, result:, distance: }]
    class TargetResolution
      def initialize(targets:, impact_xyz:, trace: nil)
        @targets = targets
        @impact_point = Artillery::Physics::Vector.from_array(impact_xyz)
        @trace = trace
      end

      def evaluate
        @targets.map do |target|
          distance = target.position.distance_to(@impact_point)
          result = classify_hit(target, distance)

          {
            target: target,
            result: result,
            distance: distance
          }
        end
      end

      private

      def classify_hit(target, distance)
        case target.material
        when :paper
          distance <= 5 ? :destroyed : :missed
        when :wood
          distance <= 2 ? :damaged : :missed
        when :metal
          distance <= 1 ? :dented : :resistant
        else
          :unknown
        end
      end
    end
  end
end
