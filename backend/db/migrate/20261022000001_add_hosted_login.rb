class AddHostedLogin < ActiveRecord::Migration[8.1]
  def change
    create_table :browser_sessions do |t|
      t.references :project, null: false
      t.references :end_user, null: false
      t.string :token_digest, null: false, index: { unique: true }
      t.jsonb :amr, null: false, default: []
      t.datetime :authenticated_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end

    add_column :auth_configurations, :sso_session_ttl_seconds, :integer, null: false, default: 28_800
    add_column :app_clients, :post_logout_redirect_uris, :jsonb, null: false, default: []
  end
end
