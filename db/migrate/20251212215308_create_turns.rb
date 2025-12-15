class CreateTurns < ActiveRecord::Migration[8.1]
  def change
    create_table :turns do |t|
      t.references :match, null: false, foreign_key: true
      t.references :match_player, null: false, foreign_key: true
      t.integer :turn_number, null: false
      t.jsonb :input_data, null: false, default: {}
      t.jsonb :result_data, null: false, default: {}
      t.boolean :hit_target, null: false, default: false
      t.integer :points_earned, null: false, default: 0

      t.timestamps
    end

    add_index :turns, [:match_id, :turn_number]
  end
end
