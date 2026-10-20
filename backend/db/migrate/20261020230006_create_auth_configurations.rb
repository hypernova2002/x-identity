class CreateAuthConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :auth_configurations do |t|
      t.string :owner_type, null: false
      t.bigint :owner_id, null: false
      t.string :mfa_requirement, null: false
      t.boolean :require_email_verification, null: false
      t.integer :password_min_length, null: false
      t.boolean :password_require_uppercase, null: false
      t.boolean :password_require_lowercase, null: false
      t.boolean :password_require_number, null: false
      t.boolean :password_require_symbol, null: false
      t.integer :password_max_age_days
      t.integer :lockout_threshold, null: false
      t.integer :lockout_window_minutes, null: false
      t.integer :lockout_duration_minutes, null: false
      t.integer :access_token_ttl_minutes, null: false
      t.integer :refresh_token_ttl_days, null: false
      t.integer :session_idle_timeout_minutes
      t.string :signing_algorithm, null: false
      t.integer :signing_key_rotation_days, null: false
      t.timestamps
    end

    add_index :auth_configurations, [ :owner_type, :owner_id ], unique: true
  end
end
