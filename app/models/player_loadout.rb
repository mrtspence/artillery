# frozen_string_literal: true

class PlayerLoadout < ApplicationRecord
  belongs_to :player
  has_many :player_loadout_slots, dependent: :destroy
  has_many :player_mechanisms, through: :player_loadout_slots

  validates :label, presence: true, uniqueness: { scope: :player_id }
  validates :engine_type, presence: true
  validates :platform_type, presence: true

  # Instantiate runtimes for all mechanisms in this loadout
  # @param match [Match] The match context
  # @param random_seed [Integer] Base random seed for determinism
  # @return [Array<RuntimeBase>] Array of runtime instances
  def instantiate_runtimes(match:, random_seed:)
    player_mechanisms.includes(:player_loadout_slots).map do |mechanism|
      # Each mechanism gets its own seed derived from base seed + mechanism ID
      mechanism_seed = random_seed + mechanism.id
      mechanism.to_runtime(match: match, random_seed: mechanism_seed)
    end
  end
end
