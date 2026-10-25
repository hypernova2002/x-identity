# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_26_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "accounts", force: :cascade do |t|
    t.string "uid", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
    t.index ["uid"], name: "index_accounts_on_uid", unique: true
  end

  create_table "api_grants", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "app_client_id", null: false
    t.bigint "api_resource_id", null: false
    t.jsonb "scopes", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_resource_id"], name: "index_api_grants_on_api_resource_id"
    t.index ["app_client_id", "api_resource_id"], name: "index_api_grants_on_app_client_id_and_api_resource_id", unique: true
    t.index ["app_client_id"], name: "index_api_grants_on_app_client_id"
    t.index ["uid"], name: "index_api_grants_on_uid", unique: true
  end

  create_table "api_resources", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.string "identifier", null: false
    t.jsonb "scopes", default: [], null: false
    t.integer "access_token_ttl_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "identifier"], name: "index_api_resources_on_project_id_and_identifier", unique: true
    t.index ["project_id"], name: "index_api_resources_on_project_id"
    t.index ["uid"], name: "index_api_resources_on_uid", unique: true
  end

  create_table "app_assignments", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.string "app_type", null: false
    t.bigint "app_id", null: false
    t.string "principal_type", null: false
    t.bigint "principal_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_type", "app_id", "principal_type", "principal_id"], name: "index_app_assignments_uniqueness", unique: true
    t.index ["principal_type", "principal_id"], name: "index_app_assignments_on_principal"
    t.index ["project_id"], name: "index_app_assignments_on_project_id"
    t.index ["uid"], name: "index_app_assignments_on_uid", unique: true
  end

  create_table "app_client_secrets", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "app_client_id", null: false
    t.string "digest", null: false
    t.string "last_four"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_client_id", "digest"], name: "index_app_client_secrets_on_app_client_id_and_digest"
    t.index ["app_client_id"], name: "index_app_client_secrets_on_app_client_id"
    t.index ["uid"], name: "index_app_client_secrets_on_uid", unique: true
  end

  create_table "app_clients", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.string "client_type", null: false
    t.jsonb "allowed_origins", default: [], null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "redirect_uris", default: [], null: false
    t.jsonb "post_logout_redirect_uris", default: [], null: false
    t.string "launch_url"
    t.string "system_kind"
    t.boolean "machine", default: false, null: false
    t.integer "token_requests_per_minute"
    t.index ["allowed_origins"], name: "index_app_clients_on_allowed_origins", using: :gin
    t.index ["project_id", "system_kind"], name: "index_app_clients_on_project_id_and_system_kind", unique: true, where: "(system_kind IS NOT NULL)"
    t.index ["project_id"], name: "index_app_clients_on_project_id"
    t.index ["uid"], name: "index_app_clients_on_uid", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "account_id", null: false
    t.bigint "project_id"
    t.string "action", null: false
    t.string "actor_type", null: false
    t.string "actor_uid"
    t.string "actor_label"
    t.string "target_type"
    t.string "target_uid"
    t.string "target_label"
    t.string "ip"
    t.string "user_agent"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "app_client_uid"
    t.string "saml_app_uid"
    t.index ["account_id", "actor_uid", "occurred_at"], name: "index_audit_events_on_account_id_and_actor_uid_and_occurred_at", where: "(actor_uid IS NOT NULL)"
    t.index ["account_id", "occurred_at"], name: "index_audit_events_on_account_id_and_occurred_at"
    t.index ["account_id", "target_uid", "occurred_at"], name: "idx_on_account_id_target_uid_occurred_at_736f07a1f2", where: "(target_uid IS NOT NULL)"
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["project_id", "action", "occurred_at"], name: "index_audit_events_on_project_id_and_action_and_occurred_at", opclass: { action: :text_pattern_ops }
    t.index ["project_id", "actor_uid", "occurred_at"], name: "index_audit_events_on_project_id_and_actor_uid_and_occurred_at", where: "(actor_uid IS NOT NULL)"
    t.index ["project_id", "app_client_uid", "occurred_at"], name: "idx_on_project_id_app_client_uid_occurred_at_b2ecb1bc0a", where: "(app_client_uid IS NOT NULL)"
    t.index ["project_id", "occurred_at"], name: "index_audit_events_on_project_id_and_occurred_at"
    t.index ["project_id", "saml_app_uid", "occurred_at"], name: "idx_on_project_id_saml_app_uid_occurred_at_751251e73a", where: "(saml_app_uid IS NOT NULL)"
    t.index ["project_id", "target_uid", "occurred_at"], name: "idx_on_project_id_target_uid_occurred_at_7eb67dbe53", where: "(target_uid IS NOT NULL)"
    t.index ["project_id"], name: "index_audit_events_on_project_id"
    t.index ["uid"], name: "index_audit_events_on_uid", unique: true
  end

  create_table "auth_configurations", force: :cascade do |t|
    t.string "owner_type", null: false
    t.bigint "owner_id", null: false
    t.string "mfa_requirement", null: false
    t.boolean "require_email_verification", null: false
    t.integer "password_min_length", null: false
    t.boolean "password_require_uppercase", null: false
    t.boolean "password_require_lowercase", null: false
    t.boolean "password_require_number", null: false
    t.boolean "password_require_symbol", null: false
    t.integer "password_max_age_seconds"
    t.integer "lockout_threshold", null: false
    t.integer "lockout_window_seconds", null: false
    t.integer "lockout_duration_seconds", null: false
    t.integer "access_token_ttl_seconds", null: false
    t.integer "refresh_token_ttl_seconds", null: false
    t.integer "session_idle_timeout_seconds"
    t.string "signing_algorithm", null: false
    t.integer "signing_key_rotation_seconds", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "mfa_max_failed_attempts", default: 5, null: false
    t.integer "email_code_max_attempts", default: 5, null: false
    t.integer "email_code_max_failures_per_email", default: 10, null: false
    t.integer "email_code_max_failures_per_code", default: 5, null: false
    t.integer "email_code_failure_window_seconds", default: 3600, null: false
    t.integer "otp_digits", default: 6, null: false
    t.integer "otp_step_seconds", default: 30, null: false
    t.integer "otp_drift_steps", default: 1, null: false
    t.integer "otp_hotp_look_ahead", default: 10, null: false
    t.string "otp_method", default: "totp", null: false
    t.integer "sso_session_ttl_seconds", default: 28800, null: false
    t.boolean "notify_new_devices", default: true, null: false
    t.integer "client_secret_rotation_overlap_seconds", default: 604800, null: false
    t.integer "token_requests_per_minute", default: 120, null: false
    t.index ["owner_type", "owner_id"], name: "index_auth_configurations_on_owner_type_and_owner_id", unique: true
  end

  create_table "browser_session_apps", force: :cascade do |t|
    t.bigint "browser_session_id", null: false
    t.bigint "saml_app_id", null: false
    t.string "name_id", null: false
    t.string "session_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["browser_session_id", "saml_app_id"], name: "idx_on_browser_session_id_saml_app_id_07b3c7817a", unique: true
    t.index ["saml_app_id"], name: "index_browser_session_apps_on_saml_app_id"
  end

  create_table "browser_sessions", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "end_user_id", null: false
    t.string "token_digest", null: false
    t.jsonb "amr", default: [], null: false
    t.datetime "authenticated_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "identity_provider_id"
    t.string "upstream_name_id"
    t.string "upstream_name_id_format"
    t.string "upstream_session_index"
    t.bigint "device_session_id"
    t.index ["device_session_id"], name: "index_browser_sessions_on_device_session_id"
    t.index ["end_user_id"], name: "index_browser_sessions_on_end_user_id"
    t.index ["identity_provider_id"], name: "index_browser_sessions_on_identity_provider_id"
    t.index ["project_id"], name: "index_browser_sessions_on_project_id"
    t.index ["token_digest"], name: "index_browser_sessions_on_token_digest", unique: true
  end

  create_table "consumed_saml_assertions", force: :cascade do |t|
    t.bigint "identity_provider_id", null: false
    t.string "assertion_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["expires_at"], name: "index_consumed_saml_assertions_on_expires_at"
    t.index ["identity_provider_id", "assertion_id"], name: "index_consumed_saml_assertions_uniqueness", unique: true
  end

  create_table "device_sessions", force: :cascade do |t|
    t.string "uid", null: false
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.bigint "project_id"
    t.string "created_ip"
    t.string "created_user_agent"
    t.string "last_ip"
    t.string "last_user_agent"
    t.string "device_name"
    t.string "device_type"
    t.string "city"
    t.string "region"
    t.string "country_code"
    t.jsonb "amr", default: [], null: false
    t.datetime "authenticated_at", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_device_sessions_on_project_id"
    t.index ["subject_type", "subject_id"], name: "index_device_sessions_on_subject"
    t.index ["uid"], name: "index_device_sessions_on_uid", unique: true
  end

  create_table "end_user_attribute_definitions", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.string "data_type", null: false
    t.boolean "required", default: false, null: false
    t.integer "max_length"
    t.boolean "user_editable", default: true, null: false
    t.boolean "include_in_token", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "key"], name: "index_end_user_attribute_definitions_on_project_id_and_key", unique: true
    t.index ["uid"], name: "index_end_user_attribute_definitions_on_uid", unique: true
  end

  create_table "end_user_identities", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "end_user_id", null: false
    t.bigint "identity_provider_id", null: false
    t.string "subject", null: false
    t.string "email"
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["end_user_id", "identity_provider_id"], name: "idx_on_end_user_id_identity_provider_id_2bf08fa548", unique: true
    t.index ["end_user_id"], name: "index_end_user_identities_on_end_user_id"
    t.index ["identity_provider_id", "subject"], name: "index_end_user_identities_on_identity_provider_id_and_subject", unique: true
    t.index ["identity_provider_id"], name: "index_end_user_identities_on_identity_provider_id"
    t.index ["uid"], name: "index_end_user_identities_on_uid", unique: true
  end

  create_table "end_users", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest"
    t.string "status", null: false
    t.jsonb "custom_attributes", default: {}, null: false
    t.datetime "email_verified_at"
    t.datetime "password_changed_at"
    t.datetime "tokens_valid_after"
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "failed_mfa_attempts", default: 0, null: false
    t.index ["email"], name: "index_end_users_on_email_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["name"], name: "index_end_users_on_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["project_id", "created_at", "id"], name: "index_end_users_on_project_id_and_created_at_and_id"
    t.index ["project_id", "email"], name: "index_end_users_on_project_id_and_email", unique: true
    t.index ["uid"], name: "index_end_users_on_uid", unique: true
    t.index ["uid"], name: "index_end_users_on_uid_trigram", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "group_memberships", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "end_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["end_user_id"], name: "index_group_memberships_on_end_user_id"
    t.index ["group_id", "end_user_id"], name: "index_group_memberships_on_group_id_and_end_user_id", unique: true
  end

  create_table "groups", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.string "description"
    t.boolean "default_for_new_users", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_groups_on_project_id_and_name", unique: true
    t.index ["uid"], name: "index_groups_on_uid", unique: true
  end

  create_table "identity_provider_group_mappings", force: :cascade do |t|
    t.bigint "identity_provider_id", null: false
    t.bigint "group_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_identity_provider_group_mappings_on_group_id"
    t.index ["identity_provider_id", "value", "group_id"], name: "index_identity_provider_group_mappings_uniqueness", unique: true
  end

  create_table "identity_providers", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.boolean "enabled", default: true, null: false
    t.string "client_id"
    t.text "client_secret"
    t.jsonb "additional_audiences", default: [], null: false
    t.string "scopes", default: "openid email profile", null: false
    t.string "discovery_url"
    t.jsonb "metadata", default: {}, null: false
    t.string "apple_team_id"
    t.string "apple_key_id"
    t.text "apple_private_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "saml_idp_entity_id"
    t.string "saml_sso_url"
    t.string "saml_slo_url"
    t.jsonb "saml_idp_certificates", default: [], null: false
    t.string "saml_name_id_format", default: "email", null: false
    t.string "saml_email_attribute"
    t.string "saml_name_attribute"
    t.string "saml_groups_attribute"
    t.jsonb "domains", default: [], null: false
    t.boolean "create_users", default: false, null: false
    t.boolean "allow_idp_initiated", default: false, null: false
    t.index ["project_id"], name: "index_identity_providers_on_project_id"
    t.index ["uid"], name: "index_identity_providers_on_uid", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "account_id", null: false
    t.bigint "invited_by_id"
    t.string "email", null: false
    t.string "role", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_invitations_on_account_id_and_email"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
    t.index ["uid"], name: "index_invitations_on_uid", unique: true
  end

  create_table "one_time_tokens", force: :cascade do |t|
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "purpose", null: false
    t.string "token_digest", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code_digest"
    t.integer "failed_attempts", default: 0, null: false
    t.index ["subject_type", "subject_id", "purpose"], name: "idx_on_subject_type_subject_id_purpose_c20527dd28"
    t.index ["token_digest"], name: "index_one_time_tokens_on_token_digest", unique: true
  end

  create_table "otp_credentials", force: :cascade do |t|
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.text "secret", null: false
    t.datetime "confirmed_at"
    t.bigint "last_verified_timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "otp_type", default: "totp", null: false
    t.integer "digits", default: 6, null: false
    t.integer "step_seconds", default: 30, null: false
    t.bigint "counter", default: 0, null: false
    t.index ["subject_type", "subject_id"], name: "index_otp_credentials_on_subject_type_and_subject_id", unique: true
  end

  create_table "project_domains", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.string "hostname", null: false
    t.string "status", null: false
    t.string "verification_token", null: false
    t.datetime "verified_at"
    t.datetime "last_checked_at"
    t.integer "check_attempts", default: 0, null: false
    t.string "check_error"
    t.datetime "dns_missing_since"
    t.string "certificate_status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hostname"], name: "index_project_domains_on_hostname", unique: true
    t.index ["project_id"], name: "index_project_domains_one_unverified", unique: true, where: "((status)::text <> 'verified'::text)"
    t.index ["project_id"], name: "index_project_domains_one_verified", unique: true, where: "((status)::text = 'verified'::text)"
    t.index ["uid"], name: "index_project_domains_on_uid", unique: true
  end

  create_table "project_memberships", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_project_memberships_on_project_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "allow_self_sign_up", default: true, null: false
    t.string "confirm_sign_up_url"
    t.string "reset_password_url"
    t.string "accept_invitation_url"
    t.datetime "deleted_at"
    t.index ["account_id"], name: "index_projects_on_account_id"
    t.index ["uid"], name: "index_projects_on_uid", unique: true
  end

  create_table "recovery_codes", force: :cascade do |t|
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "code_digest", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code_digest"], name: "index_recovery_codes_on_code_digest"
    t.index ["subject_type", "subject_id"], name: "index_recovery_codes_on_subject_type_and_subject_id"
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "token_digest", null: false
    t.string "family_id", null: false
    t.datetime "authenticated_at", null: false
    t.jsonb "amr", default: [], null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "app_client_id"
    t.string "scope"
    t.bigint "device_session_id"
    t.index ["app_client_id"], name: "index_refresh_tokens_on_app_client_id"
    t.index ["device_session_id"], name: "index_refresh_tokens_on_device_session_id"
    t.index ["family_id"], name: "index_refresh_tokens_on_family_id"
    t.index ["subject_type", "subject_id"], name: "index_refresh_tokens_on_subject_type_and_subject_id"
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
  end

  create_table "saml_apps", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.boolean "enabled", default: true, null: false
    t.string "entity_id", null: false
    t.jsonb "acs_urls", default: [], null: false
    t.string "slo_url"
    t.text "sp_certificate"
    t.string "name_id_format", default: "email", null: false
    t.jsonb "attribute_mappings", default: [], null: false
    t.boolean "sign_assertion", default: true, null: false
    t.boolean "sign_response", default: false, null: false
    t.boolean "require_signed_requests", default: false, null: false
    t.string "default_relay_state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "entity_id"], name: "index_saml_apps_on_project_id_and_entity_id", unique: true
    t.index ["uid"], name: "index_saml_apps_on_uid", unique: true
  end

  create_table "saml_certificates", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "project_id", null: false
    t.text "private_key", null: false
    t.text "certificate", null: false
    t.string "status", null: false
    t.datetime "activated_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_saml_certificates_on_project_id"
    t.index ["uid"], name: "index_saml_certificates_on_uid", unique: true
  end

  create_table "signing_keys", force: :cascade do |t|
    t.string "owner_type", null: false
    t.bigint "owner_id", null: false
    t.string "kid", null: false
    t.string "algorithm", null: false
    t.text "public_key", null: false
    t.text "private_key", null: false
    t.datetime "activated_at", null: false
    t.datetime "retired_at"
    t.datetime "published_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kid"], name: "index_signing_keys_on_kid", unique: true
    t.index ["owner_type", "owner_id"], name: "index_signing_keys_on_owner_type_and_owner_id"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "uid", null: false
    t.bigint "account_id", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", null: false
    t.string "status", null: false
    t.datetime "email_verified_at"
    t.datetime "password_changed_at", null: false
    t.datetime "tokens_valid_after"
    t.datetime "last_sign_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "failed_mfa_attempts", default: 0, null: false
    t.index ["account_id", "email"], name: "index_users_on_account_id_and_email", unique: true
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "api_grants", "api_resources", on_delete: :cascade
  add_foreign_key "api_grants", "app_clients", on_delete: :cascade
  add_foreign_key "api_resources", "projects", on_delete: :cascade
  add_foreign_key "app_client_secrets", "app_clients", on_delete: :cascade
  add_foreign_key "browser_sessions", "device_sessions", on_delete: :nullify
  add_foreign_key "device_sessions", "projects", on_delete: :cascade
  add_foreign_key "project_domains", "projects"
  add_foreign_key "refresh_tokens", "device_sessions", on_delete: :nullify
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
