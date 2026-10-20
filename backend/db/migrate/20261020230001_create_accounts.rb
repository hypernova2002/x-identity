class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :uid, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end

    add_index :accounts, :uid, unique: true
    add_index :accounts, :slug, unique: true
  end
end
