class CreateSigningKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :signing_keys do |t|
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      t.string :kid, null: false
      t.string :algorithm, null: false
      t.text :public_key, null: false
      t.text :private_key, null: false
      t.datetime :activated_at, null: false
      t.datetime :retired_at
      t.datetime :published_until
      t.timestamps
    end

    add_index :signing_keys, :kid, unique: true
    add_index :signing_keys, [ :owner_type, :owner_id ]
  end
end
