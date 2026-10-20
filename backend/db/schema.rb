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

ActiveRecord::Schema[8.1].define(version: 2026_10_20_230012) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "uid", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
    t.index ["uid"], name: "index_accounts_on_uid", unique: true
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
    t.index ["account_id", "occurred_at"], name: "index_audit_events_on_account_id_and_occurred_at"
    t.index ["action"], name: "index_audit_events_on_action"
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
    t.integer "password_max_age_days"
    t.integer "lockout_threshold", null: false
    t.integer "lockout_window_minutes", null: false
    t.integer "lockout_duration_minutes", null: false
    t.integer "access_token_ttl_minutes", null: false
    t.integer "refresh_token_ttl_days", null: false
    t.integer "session_idle_timeout_minutes"
    t.string "signing_algorithm", null: false
    t.integer "signing_key_rotation_days", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_auth_configurations_on_owner_type_and_owner_id", unique: true
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
    t.index ["subject_type", "subject_id"], name: "index_otp_credentials_on_subject_type_and_subject_id", unique: true
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
    t.index ["family_id"], name: "index_refresh_tokens_on_family_id"
    t.index ["subject_type", "subject_id"], name: "index_refresh_tokens_on_subject_type_and_subject_id"
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
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
    t.index ["account_id", "email"], name: "index_users_on_account_id_and_email", unique: true
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end
end
