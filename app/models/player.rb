class Player < ApplicationRecord
  has_many :player_mechanisms, dependent: :destroy
  has_many :player_loadouts, dependent: :destroy

  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
