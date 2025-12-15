FactoryBot.define do
  factory :match_player do
    match { nil }
    player { nil }
    player_loadout { nil }
    position_on_map { "" }
    turn_order { 1 }
    is_host { false }
    score { 1 }
  end
end
