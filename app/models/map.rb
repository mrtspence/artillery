class Map < ApplicationRecord
  # Associations
  belongs_to :match
  has_many :map_targets, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :width, presence: true, numericality: { greater_than: 0 }
  validates :height, presence: true, numericality: { greater_than: 0 }
  validates :terrain_data, presence: true
end
