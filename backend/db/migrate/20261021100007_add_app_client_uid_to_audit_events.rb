class AddAppClientUidToAuditEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :audit_events, :app_client_uid, :string
    add_index :audit_events, [ :project_id, :occurred_at ]
  end
end
