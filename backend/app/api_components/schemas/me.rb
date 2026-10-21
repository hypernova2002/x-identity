class Schemas::Me < Schemas::User
  schema(
    required: %w[password_changed_at otp_method account],
    properties: {
      password_changed_at: { type: :string, format: "date-time" },
      otp_method: { type: :string, enum: AuthConfiguration::OTP_METHODS, description: "The method used when setting up MFA." },
      account: Schemas::Account
    }
  )
end
