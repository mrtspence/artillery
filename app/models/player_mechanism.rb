# frozen_string_literal: true

class PlayerMechanism < ApplicationRecord
  belongs_to :player
  has_many :player_loadout_slots, dependent: :restrict_with_error
  has_many :player_loadouts, through: :player_loadout_slots

  # STI configuration
  self.inheritance_column = 'type'

  validates :type, presence: true
  validates :slot_key, presence: true
  validates :upgrade_level, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :priority, presence: true, numericality: { only_integer: true }

  # Generate runtime instance for a match
  # @param match [Match] The match context
  # @param random_seed [Integer] Deterministic random seed
  # @return [RuntimeBase] Runtime instance for this mechanism
  def to_runtime(match:, random_seed:)
    runtime_class.new(
      mechanism: self,
      match: match,
      random_seed: random_seed
    )
  end

  # Override in subclasses to specify runtime class
  # @return [Class] Runtime class for this mechanism
  def runtime_class
    raise NotImplementedError, "#{self.class.name} must implement #runtime_class"
  end

  # Declare which input keys this mechanism consumes
  # @return [Array<Symbol>] Input keys
  def input_keys
    []
  end

  # Declare which output keys this mechanism produces
  # @return [Array<Symbol>] Output keys
  def output_keys
    []
  end
end
