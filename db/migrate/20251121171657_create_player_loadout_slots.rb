class CreatePlayerLoadoutSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :player_loadout_slots do |t|
      t.references :player_loadout, null: false, foreign_key: true
      t.references :player_mechanism, null: false, foreign_key: true
      t.string :slot_key, null: false

      t.timestamps
    end

    add_index :player_loadout_slots, [:player_loadout_id, :slot_key], unique: true, name: 'index_loadout_slots_on_loadout_and_slot'
  end
end
