class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.string :uid, null: false
      t.bigint :account_id, null: false
      t.bigint :invited_by_id
      t.string :email, null: false
      t.string :role, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :invitations, :uid, unique: true
    add_index :invitations, :token_digest, unique: true
    add_index :invitations, [ :account_id, :email ]
    add_index :invitations, :invited_by_id
  end
end
