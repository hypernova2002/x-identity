class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :uid, null: false
      t.bigint :account_id, null: false
      t.string :email, null: false
      t.string :name, null: false
      t.string :password_digest, null: false
      t.string :role, null: false
      t.string :status, null: false
      t.datetime :email_verified_at
      t.datetime :password_changed_at, null: false
      t.datetime :tokens_valid_after
      t.datetime :last_sign_in_at
      t.timestamps
    end

    add_index :users, :uid, unique: true
    add_index :users, [ :account_id, :email ], unique: true
  end
end
