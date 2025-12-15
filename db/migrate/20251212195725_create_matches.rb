class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.string :status, null: false, default: 'setup'
      t.string :lobby_code, null: false, limit: 6
      t.references :current_player, foreign_key: { to_table: :players }

      t.timestamps
    end

    add_index :matches, :status
    add_index :matches, :lobby_code, unique: true
  end
end
