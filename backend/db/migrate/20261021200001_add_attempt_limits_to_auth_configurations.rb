class AddAttemptLimitsToAuthConfigurations < ActiveRecord::Migration[8.1]
  def change
    add_column :auth_configurations, :mfa_max_failed_attempts, :integer, null: false, default: 5
    add_column :auth_configurations, :email_code_max_attempts, :integer, null: false, default: 5
    add_column :auth_configurations, :email_code_max_failures_per_email_hour, :integer, null: false, default: 10
    add_column :auth_configurations, :email_code_max_failures_per_code_hour, :integer, null: false, default: 5
  end
end
