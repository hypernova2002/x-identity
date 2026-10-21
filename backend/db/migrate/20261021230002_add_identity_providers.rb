class AddIdentityProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :identity_providers do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :project, null: false
      t.string :kind, null: false
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.string :client_id, null: false
      t.text :client_secret
      t.jsonb :additional_audiences, null: false, default: []
      t.string :scopes, null: false, default: "openid email profile"
      t.string :discovery_url
      t.jsonb :metadata, null: false, default: {}
      t.string :apple_team_id
      t.string :apple_key_id
      t.text :apple_private_key
      t.timestamps
    end

    create_table :end_user_identities do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :end_user, null: false
      t.references :identity_provider, null: false
      t.string :subject, null: false
      t.string :email
      t.datetime :last_sign_in_at
      t.timestamps
      t.index %i[identity_provider_id subject], unique: true
      t.index %i[end_user_id identity_provider_id], unique: true
    end

    add_column :app_clients, :redirect_uris, :jsonb, null: false, default: []
  end
end
