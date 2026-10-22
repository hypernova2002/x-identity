class AddSamlIdentityProviders < ActiveRecord::Migration[8.1]
  def change
    change_table :identity_providers, bulk: true do |t|
      t.change_null :client_id, true
      t.string :saml_idp_entity_id
      t.string :saml_sso_url
      t.string :saml_slo_url
      t.jsonb :saml_idp_certificates, null: false, default: []
      t.string :saml_name_id_format, null: false, default: "email"
      t.string :saml_email_attribute
      t.string :saml_name_attribute
      t.string :saml_groups_attribute
      t.jsonb :domains, null: false, default: []
      t.boolean :create_users, null: false, default: false
      t.boolean :allow_idp_initiated, null: false, default: false
    end

    create_table :identity_provider_group_mappings do |t|
      t.references :identity_provider, null: false, index: false
      t.references :group, null: false
      t.string :value, null: false
      t.timestamps
      t.index %i[identity_provider_id value group_id], unique: true, name: "index_identity_provider_group_mappings_uniqueness"
    end

    create_table :consumed_saml_assertions do |t|
      t.references :identity_provider, null: false, index: false
      t.string :assertion_id, null: false
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
      t.index %i[identity_provider_id assertion_id], unique: true, name: "index_consumed_saml_assertions_uniqueness"
      t.index :expires_at
    end

    change_table :browser_sessions, bulk: true do |t|
      t.references :identity_provider
      t.string :upstream_name_id
      t.string :upstream_name_id_format
      t.string :upstream_session_index
    end
  end
end
