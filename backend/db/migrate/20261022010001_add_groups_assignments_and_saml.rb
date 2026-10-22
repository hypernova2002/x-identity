class AddGroupsAssignmentsAndSaml < ActiveRecord::Migration[8.1]
  def up
    create_table :groups do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :project, null: false, index: false
      t.string :name, null: false
      t.string :description
      t.boolean :default_for_new_users, null: false, default: false
      t.timestamps
      t.index %i[project_id name], unique: true
    end

    create_table :group_memberships do |t|
      t.references :group, null: false, index: false
      t.references :end_user, null: false
      t.timestamps
      t.index %i[group_id end_user_id], unique: true
    end

    create_table :app_assignments do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :project, null: false
      t.references :app, polymorphic: true, null: false, index: false
      t.references :principal, polymorphic: true, null: false
      t.timestamps
      t.index %i[app_type app_id principal_type principal_id], unique: true, name: "index_app_assignments_uniqueness"
    end

    create_table :saml_apps do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :project, null: false, index: false
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.string :entity_id, null: false
      t.jsonb :acs_urls, null: false, default: []
      t.string :slo_url
      t.text :sp_certificate
      t.string :name_id_format, null: false, default: "email"
      t.jsonb :attribute_mappings, null: false, default: []
      t.boolean :sign_assertion, null: false, default: true
      t.boolean :sign_response, null: false, default: false
      t.boolean :require_signed_requests, null: false, default: false
      t.string :default_relay_state
      t.timestamps
      t.index %i[project_id entity_id], unique: true
    end

    create_table :saml_certificates do |t|
      t.string :uid, null: false, index: { unique: true }
      t.references :project, null: false
      t.text :private_key, null: false
      t.text :certificate, null: false
      t.string :status, null: false
      t.datetime :activated_at
      t.datetime :expires_at, null: false
      t.timestamps
    end

    create_table :browser_session_apps do |t|
      t.references :browser_session, null: false, index: false
      t.references :saml_app, null: false
      t.string :name_id, null: false
      t.string :session_index, null: false
      t.timestamps
      t.index %i[browser_session_id saml_app_id], unique: true
    end

    add_column :app_clients, :launch_url, :string
    add_column :refresh_tokens, :scope, :string
    add_column :app_clients, :system_kind, :string
    add_index :app_clients, %i[project_id system_kind], unique: true, where: "system_kind IS NOT NULL"

    backfill_all_end_users_groups
  end

  def down
    remove_index :app_clients, %i[project_id system_kind]
    remove_column :app_clients, :system_kind
    remove_column :refresh_tokens, :scope
    remove_column :app_clients, :launch_url
    drop_table :browser_session_apps
    drop_table :saml_certificates
    drop_table :saml_apps
    drop_table :app_assignments
    drop_table :group_memberships
    drop_table :groups
  end

  private

  # Apps now need an assignment, so existing projects get a group of everyone, which new users join
  # too, assigned to every existing app client, to keep current sign-ins and sign-ups working.
  def backfill_all_end_users_groups
    select_values("SELECT id FROM projects").each do |project_id|
      group_id = select_value(sql(
        "INSERT INTO groups (uid, project_id, name, description, default_for_new_users, created_at, updated_at) " \
        "VALUES (?, ?, ?, ?, TRUE, NOW(), NOW()) RETURNING id",
        "grp_#{SecureRandom.base58(24)}", project_id, "All end users", "Every end user, including new ones."
      ))
      execute(sql(
        "INSERT INTO group_memberships (group_id, end_user_id, created_at, updated_at) SELECT ?, id, NOW(), NOW() FROM end_users WHERE project_id = ?",
        group_id, project_id
      ))
      select_values(sql("SELECT id FROM app_clients WHERE project_id = ?", project_id)).each do |app_client_id|
        execute(sql(
          "INSERT INTO app_assignments (uid, project_id, app_type, app_id, principal_type, principal_id, created_at, updated_at) " \
          "VALUES (?, ?, 'AppClient', ?, 'Group', ?, NOW(), NOW())",
          "asg_#{SecureRandom.base58(24)}", project_id, app_client_id, group_id
        ))
      end
    end
  end

  def sql(statement, *values)
    ActiveRecord::Base.sanitize_sql_array([ statement, *values ])
  end
end
