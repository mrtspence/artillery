class MatchPlayer < ApplicationRecord
  # Associations
  belongs_to :match
  belongs_to :player
  belongs_to :player_loadout
  has_many :turns, dependent: :destroy

  # Validations
  validates :player_id, uniqueness: { scope: :match_id }
  validates :turn_order, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :turn_order, uniqueness: { scope: :match_id }
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0 }
  # position_on_map is set dynamically during match, can be empty initially

  # Scopes
  scope :by_turn_order, -> { order(:turn_order) }
  scope :hosts, -> { where(is_host: true) }
end
