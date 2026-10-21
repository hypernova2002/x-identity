class CreateEndUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :end_users do |t|
      t.string :uid, null: false
      t.bigint :project_id, null: false
      t.string :email, null: false
      t.string :name
      t.string :password_digest
      t.string :status, null: false
      t.jsonb :custom_attributes, null: false, default: {}
      t.datetime :email_verified_at
      t.datetime :password_changed_at
      t.datetime :tokens_valid_after
      t.datetime :last_sign_in_at
      t.timestamps
    end

    add_index :end_users, :uid, unique: true
    add_index :end_users, [ :project_id, :email ], unique: true
  end
end
