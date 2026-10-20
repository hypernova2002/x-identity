class CreateOtpCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :otp_credentials do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.text :secret, null: false
      t.datetime :confirmed_at
      t.bigint :last_verified_timestamp
      t.timestamps
    end

    add_index :otp_credentials, [ :subject_type, :subject_id ], unique: true
  end
end
