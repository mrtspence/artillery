class RemoveEmailFromPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_column :players, :email, :string
  end
end
