# Indexes for the audit log's filters and the end-user directory's sort and search. Built
# concurrently so large tables keep taking writes while they're created.
class AddQueryIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  AUDIT_FILTERS = %i[app_client_uid saml_app_uid target_uid actor_uid].freeze

  def up
    AUDIT_FILTERS.each do |column|
      add_index :audit_events, [ :project_id, column, :occurred_at ], where: "#{column} IS NOT NULL", algorithm: :concurrently,
        if_not_exists: true
    end
    %i[target_uid actor_uid].each do |column|
      add_index :audit_events, [ :account_id, column, :occurred_at ], where: "#{column} IS NOT NULL", algorithm: :concurrently, if_not_exists: true
    end
    # text_pattern_ops lets "action starts with" (LIKE 'prefix%') use the index as well as equality.
    add_index :audit_events, %i[project_id action occurred_at], opclass: { action: :text_pattern_ops }, algorithm: :concurrently, if_not_exists: true

    add_index :end_users, %i[project_id created_at id], algorithm: :concurrently, if_not_exists: true
    enable_extension "pg_trgm"
    %i[email name uid].each do |column|
      add_index :end_users, column, using: :gin, opclass: :gin_trgm_ops, name: "index_end_users_on_#{column}_trigram", algorithm: :concurrently,
        if_not_exists: true
    end
  end

  def down
    %i[email name uid].each { |column| remove_index :end_users, name: "index_end_users_on_#{column}_trigram", algorithm: :concurrently, if_exists: true }
    remove_index :end_users, %i[project_id created_at id], algorithm: :concurrently, if_exists: true
    remove_index :audit_events, %i[project_id action occurred_at], algorithm: :concurrently, if_exists: true
    %i[target_uid actor_uid].each { |column| remove_index :audit_events, [ :account_id, column, :occurred_at ], algorithm: :concurrently, if_exists: true }
    AUDIT_FILTERS.each { |column| remove_index :audit_events, [ :project_id, column, :occurred_at ], algorithm: :concurrently, if_exists: true }
  end
end
