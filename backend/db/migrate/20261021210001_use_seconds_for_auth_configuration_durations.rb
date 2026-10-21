class UseSecondsForAuthConfigurationDurations < ActiveRecord::Migration[8.1]
  MINUTE = 60
  DAY = 86_400

  CONVERSIONS = [
    [ :password_max_age_days, :password_max_age_seconds, DAY ],
    [ :lockout_window_minutes, :lockout_window_seconds, MINUTE ],
    [ :lockout_duration_minutes, :lockout_duration_seconds, MINUTE ],
    [ :access_token_ttl_minutes, :access_token_ttl_seconds, MINUTE ],
    [ :refresh_token_ttl_days, :refresh_token_ttl_seconds, DAY ],
    [ :session_idle_timeout_minutes, :session_idle_timeout_seconds, MINUTE ],
    [ :signing_key_rotation_days, :signing_key_rotation_seconds, DAY ]
  ].freeze

  def up
    CONVERSIONS.each do |from, to, factor|
      rename_column :auth_configurations, from, to
      execute "UPDATE auth_configurations SET #{to} = #{to} * #{factor}"
    end

    rename_column :auth_configurations, :email_code_max_failures_per_email_hour, :email_code_max_failures_per_email
    rename_column :auth_configurations, :email_code_max_failures_per_code_hour, :email_code_max_failures_per_code
    add_column :auth_configurations, :email_code_failure_window_seconds, :integer, null: false, default: 3600
  end

  def down
    remove_column :auth_configurations, :email_code_failure_window_seconds
    rename_column :auth_configurations, :email_code_max_failures_per_code, :email_code_max_failures_per_code_hour
    rename_column :auth_configurations, :email_code_max_failures_per_email, :email_code_max_failures_per_email_hour

    CONVERSIONS.each do |from, to, factor|
      execute "UPDATE auth_configurations SET #{to} = #{to} / #{factor}"
      rename_column :auth_configurations, to, from
    end
  end
end
