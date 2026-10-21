class UseSingleOtpMethod < ActiveRecord::Migration[8.1]
  def up
    add_column :auth_configurations, :otp_method, :string, null: false, default: "totp"
    execute "UPDATE auth_configurations SET otp_method = otp_methods->>0 WHERE otp_methods->>0 IS NOT NULL"
    remove_column :auth_configurations, :otp_methods
  end

  def down
    add_column :auth_configurations, :otp_methods, :jsonb, null: false, default: [ "totp" ]
    execute "UPDATE auth_configurations SET otp_methods = jsonb_build_array(otp_method)"
    remove_column :auth_configurations, :otp_method
  end
end
