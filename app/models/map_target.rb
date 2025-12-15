class MapTarget < ApplicationRecord
  # Associations
  belongs_to :map

  # Validations
  validates :name, presence: true
  validates :target_type, presence: true
  validates :position, presence: true
  validates :points_value, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :hit, -> { where(is_hit: true) }
  scope :unhit, -> { where(is_hit: false) }

  # Methods
  def mark_as_hit!
    update!(is_hit: true)
  end
end
