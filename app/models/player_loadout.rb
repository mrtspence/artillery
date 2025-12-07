# frozen_string_literal: true

class PlayerLoadout < ApplicationRecord
  belongs_to :player
  has_many :player_loadout_slots, dependent: :destroy
  has_many :player_mechanisms, through: :player_loadout_slots

  accepts_nested_attributes_for :player_loadout_slots, allow_destroy: true

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

  # Get the platform definition object
  # @return [Class] Platform class
  # @raise [Artillery::Platforms::UnknownPlatformError] if platform not found
  def platform
    @platform ||= Artillery::Platforms::Registry.get(platform_type)
  end

  # Get unfilled required slots
  # @return [Array<Symbol>] Array of missing required slot keys
  def missing_required_slots
    return [] unless platform_type.present?

    # Include both persisted and in-memory slots
    mechanisms = player_loadout_slots.map(&:player_mechanism).compact
    filled_slots = mechanisms.map(&:slot_key).map(&:to_sym)
    platform.required_slot_keys.reject { |slot| filled_slots.include?(slot) }
  end

  # Check if loadout is complete and valid for a match
  # This is the gatekeeper - loadouts can be saved in incomplete states,
  # but cannot be used in matches until they pass platform validation
  # @return [Boolean]
  def valid_for_match?
    return false unless valid?
    return false unless platform_type.present?

    begin
      platform_errors = platform.validate_loadout(self)
      platform_errors.empty?
    rescue Artillery::Platforms::UnknownPlatformError
      false
    end
  end

  # Get platform validation errors for UI display
  # @return [Array<String>] Array of error messages
  def platform_validation_errors
    return [] unless platform_type.present?

    begin
      platform.validate_loadout(self)
    rescue Artillery::Platforms::UnknownPlatformError => e
      [e.message]
    end
  end

  # Get allowed mechanism types for a slot
  # @param slot_key [Symbol, String] The slot key
  # @return [Array<String>] Array of allowed mechanism class names
  def allowed_mechanism_types_for_slot(slot_key)
    return [] unless platform_type.present?

    requirement = platform.slot_requirement_for(slot_key)
    requirement ? requirement.allowed_types : []
  end

end
