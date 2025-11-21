# frozen_string_literal: true

FactoryBot.define do
  factory :player_loadout do
    association :player
    sequence(:label) { |n| "Loadout #{n}" }
    engine_type { 'Ballistic3D' }
    platform_type { 'QF18Pounder' }
    default { false }

    # Trait for default loadout
    trait :default do
      default { true }
      label { "Default Configuration" }
    end

    # Trait for heavy loadout
    trait :heavy do
      label { "Heavy Artillery" }
    end

    # Trait for precision loadout
    trait :precision do
      label { "Precision Shot" }
    end
  end
end
