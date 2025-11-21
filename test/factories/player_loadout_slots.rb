# frozen_string_literal: true

FactoryBot.define do
  factory :player_loadout_slot do
    association :player_loadout
    association :player_mechanism
    slot_key { :generic }

    # Ensure slot_key matches mechanism's slot_key
    after(:build) do |slot, evaluator|
      slot.slot_key = slot.player_mechanism.slot_key if slot.player_mechanism
    end

    # Trait for cartridge slot
    trait :cartridge_slot do
      slot_key { :cartridge }
      association :player_mechanism, factory: :cartridge_85mm
    end
  end
end
