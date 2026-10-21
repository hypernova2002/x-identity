class CreateAppClients < ActiveRecord::Migration[8.1]
  def change
    create_table :app_clients do |t|
      t.string :uid, null: false
      t.bigint :project_id, null: false
      t.string :name, null: false
      t.string :client_type, null: false
      t.string :client_secret_digest
      t.jsonb :allowed_origins, null: false, default: []
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :app_clients, :uid, unique: true
    add_index :app_clients, :project_id
    add_index :app_clients, :allowed_origins, using: :gin
  end
end
