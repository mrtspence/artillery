# frozen_string_literal: true

class PlayerLoadoutSlot < ApplicationRecord
  belongs_to :player_loadout
  belongs_to :player_mechanism

  validates :slot_key, presence: true, uniqueness: { scope: :player_loadout_id }
  validate :slot_key_matches_mechanism

  private

  def slot_key_matches_mechanism
    return unless player_mechanism && slot_key

    if player_mechanism.slot_key.to_s != slot_key.to_s
      errors.add(:slot_key, "must match mechanism's slot_key (#{player_mechanism.slot_key})")
    end
  end
end
