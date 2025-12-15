class CreateMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :match_players do |t|
      t.references :match, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :player_loadout, null: false, foreign_key: true
      t.jsonb :position_on_map, null: false, default: {}
      t.integer :turn_order, null: false
      t.boolean :is_host, null: false, default: false
      t.integer :score, null: false, default: 0

      t.timestamps
    end

    add_index :match_players, [:match_id, :player_id], unique: true
    add_index :match_players, [:match_id, :turn_order]
  end
end
