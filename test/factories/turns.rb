FactoryBot.define do
  factory :turn do
    association :match
    association :match_player
    turn_number { 0 }
    input_data { {} }
    result_data { {} }
    hit_target { false }
    points_earned { 0 }

    trait :with_points do
      points_earned { 100 }
    end
  end
end
