class AddMachineToMachine < ActiveRecord::Migration[8.1]
  class MigrationAppClient < ActiveRecord::Base
    self.table_name = "app_clients"
  end

  class MigrationAppClientSecret < ActiveRecord::Base
    self.table_name = "app_client_secrets"
  end

  def up
    create_table :api_resources do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :identifier, null: false
      t.jsonb :scopes, null: false, default: []
      t.integer :access_token_ttl_seconds
      t.timestamps
      t.index %i[project_id identifier], unique: true
    end

    create_table :api_grants do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :app_client, null: false, foreign_key: { on_delete: :cascade }
      t.references :api_resource, null: false, foreign_key: { on_delete: :cascade }
      t.jsonb :scopes, null: false, default: []
      t.timestamps
      t.index %i[app_client_id api_resource_id], unique: true
    end

    add_column :app_clients, :machine, :boolean, null: false, default: false

    create_table :app_client_secrets do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :app_client, null: false, foreign_key: { on_delete: :cascade }
      t.string :digest, null: false
      t.string :last_four
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
      t.index %i[app_client_id digest]
    end

    # Each client's existing secret becomes its first secret; only its digest was ever stored.
    MigrationAppClient.where.not(client_secret_digest: nil).find_each do |client|
      MigrationAppClientSecret.create!(
        uid: "sec_#{SecureRandom.base58(24)}", app_client_id: client.id, digest: client.client_secret_digest,
        created_at: client.updated_at, updated_at: client.updated_at
      )
    end
    remove_column :app_clients, :client_secret_digest
  end

  def down
    add_column :app_clients, :client_secret_digest, :string
    execute <<~SQL
      UPDATE app_clients SET client_secret_digest = (
        SELECT digest FROM app_client_secrets
        WHERE app_client_id = app_clients.id AND revoked_at IS NULL
        ORDER BY created_at DESC LIMIT 1
      )
    SQL
    drop_table :app_client_secrets
    remove_column :app_clients, :machine
    drop_table :api_grants
    drop_table :api_resources
  end
end
