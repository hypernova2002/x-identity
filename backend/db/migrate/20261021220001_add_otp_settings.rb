class AddOtpSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :auth_configurations, :otp_methods, :jsonb, null: false, default: [ "totp" ]
    add_column :auth_configurations, :otp_digits, :integer, null: false, default: 6
    add_column :auth_configurations, :otp_step_seconds, :integer, null: false, default: 30
    add_column :auth_configurations, :otp_drift_steps, :integer, null: false, default: 1
    add_column :auth_configurations, :otp_hotp_look_ahead, :integer, null: false, default: 10

    add_column :otp_credentials, :otp_type, :string, null: false, default: "totp"
    add_column :otp_credentials, :digits, :integer, null: false, default: 6
    add_column :otp_credentials, :step_seconds, :integer, null: false, default: 30
    add_column :otp_credentials, :counter, :bigint, null: false, default: 0
  end
end
