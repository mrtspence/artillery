class CreateMatchStates < ActiveRecord::Migration[8.1]
  def change
    create_table :match_states do |t|
      t.references :match, null: false, foreign_key: true, index: { unique: true }
      t.integer :current_turn_number, null: false, default: 0
      t.integer :turn_limit, null: false, default: 10

      t.timestamps
    end
  end
end
