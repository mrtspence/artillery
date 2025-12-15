class MatchState < ApplicationRecord
  # Associations
  belongs_to :match

  # Validations
  validates :current_turn_number, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :turn_limit, presence: true, numericality: { greater_than: 0 }

  # Methods
  def turns_remaining
    turn_limit - current_turn_number
  end

  def game_over?
    current_turn_number >= turn_limit
  end

  def increment_turn!
    increment!(:current_turn_number)
  end
end
