FactoryBot.define do
  factory :match_state do
    match { nil }
    current_turn_number { 1 }
    turn_limit { 1 }
  end
end
