class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.string :uid, null: false
      t.bigint :account_id, null: false
      t.bigint :project_id
      t.string :action, null: false
      t.string :actor_type, null: false
      t.string :actor_uid
      t.string :actor_label
      t.string :target_type
      t.string :target_uid
      t.string :target_label
      t.string :ip
      t.string :user_agent
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :audit_events, :uid, unique: true
    add_index :audit_events, [ :account_id, :occurred_at ]
    add_index :audit_events, :project_id
    add_index :audit_events, :action
  end
end
