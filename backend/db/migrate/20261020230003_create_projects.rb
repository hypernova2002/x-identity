class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :uid, null: false
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :projects, :uid, unique: true
    add_index :projects, :account_id
  end
end
