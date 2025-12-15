FactoryBot.define do
  factory :match do
    # status defaults to 'setup' via model
    # lobby_code is auto-generated via callback
    # current_player is nil until match starts

    trait :with_players do
      after(:create) do |match|
        player1 = create(:player, username: "match_player_1_#{match.id}")
        player2 = create(:player, username: "match_player_2_#{match.id}")
        loadout1 = create(:player_loadout, player: player1)
        loadout2 = create(:player_loadout, player: player2)
        match.add_player!(player1, loadout1)
        match.add_player!(player2, loadout2)
      end
    end

    trait :in_progress do
      status { 'in_progress' }

      after(:create) do |match|
        unless match.match_players.any?
          player1 = create(:player, username: "match_player_1_#{match.id}")
          player2 = create(:player, username: "match_player_2_#{match.id}")
          loadout1 = create(:player_loadout, player: player1)
          loadout2 = create(:player_loadout, player: player2)
          match.add_player!(player1, loadout1)
          match.add_player!(player2, loadout2)
        end
        match.update!(current_player: match.match_players.by_turn_order.first.player)
      end
    end

    trait :completed do
      status { 'completed' }
    end

    trait :abandoned do
      status { 'abandoned' }
    end
  end
end
