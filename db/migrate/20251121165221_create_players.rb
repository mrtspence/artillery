class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :username, null: false
      t.string :email, null: false

      t.timestamps
    end

    add_index :players, :username, unique: true
    add_index :players, :email, unique: true
  end
end
