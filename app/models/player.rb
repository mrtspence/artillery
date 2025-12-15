class Player < ApplicationRecord
  has_many :player_mechanisms, dependent: :destroy
  has_many :player_loadouts, dependent: :destroy
  has_many :match_players, dependent: :destroy
  has_many :matches, through: :match_players

  validates :username, presence: true, uniqueness: true
end
