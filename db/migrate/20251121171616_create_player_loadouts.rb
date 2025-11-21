class CreatePlayerLoadouts < ActiveRecord::Migration[8.1]
  def change
    create_table :player_loadouts do |t|
      t.references :player, null: false, foreign_key: true
      t.string :label, null: false
      t.string :engine_type, default: 'ballistic_3d', null: false
      t.string :platform_type, null: false     # 'qf_18_pounder', 'mortar', etc.
      t.boolean :default, default: false, null: false

      t.timestamps
    end

    add_index :player_loadouts, [:player_id, :label], unique: true
  end
end
