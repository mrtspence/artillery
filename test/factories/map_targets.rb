FactoryBot.define do
  factory :map_target do
    association :map
    sequence(:name) { |n| "Target #{n}" }
    position { { x: 500, y: 500 } }
    target_type { "building" }
    is_hit { false }
    points_value { 50 }

    trait :high_value do
      points_value { 200 }
      target_type { "command_post" }
    end

    trait :hit do
      is_hit { true }
    end
  end
end
