class Turn < ApplicationRecord
  # Associations
  belongs_to :match
  belongs_to :match_player

  # Validations
  validates :turn_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :points_earned, presence: true, numericality: { greater_than_or_equal_to: 0 }
  # input_data and result_data can be empty hashes initially

  # Scopes
  scope :by_turn_number, -> { order(:turn_number) }

  # Delegations
  delegate :player, to: :match_player

  # Note: hit_target field exists in DB but is not actively used
  # Points calculation handles all scoring logic
end
