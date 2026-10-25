class CreateWebauthnCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :webauthn_credentials do |t|
      t.string :uid, null: false
      t.references :subject, polymorphic: true, null: false
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.jsonb :transports, null: false, default: []
      t.string :aaguid
      t.boolean :backup_eligible, null: false, default: false
      t.boolean :backed_up, null: false, default: false
      t.string :rp_id, null: false
      t.string :name, null: false
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :webauthn_credentials, :uid, unique: true
    add_index :webauthn_credentials, :external_id, unique: true

    # The opaque user handle passkeys store; random, so it says nothing about the user.
    add_column :users, :webauthn_id, :string
    add_index :users, :webauthn_id, unique: true
    add_column :end_users, :webauthn_id, :string
    add_index :end_users, :webauthn_id, unique: true

    add_column :auth_configurations, :passkeys, :string, null: false, default: "off"
  end
end
