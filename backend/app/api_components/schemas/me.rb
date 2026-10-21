class Schemas::Me < Schemas::User
  schema(
    required: %w[password_changed_at otp_methods account],
    properties: {
      password_changed_at: { type: :string, format: "date-time" },
      otp_methods: { type: :array, items: { type: :string, enum: AuthConfiguration::OTP_METHODS }, description: "Methods allowed when setting up MFA." },
      account: Schemas::Account
    }
  )
end
