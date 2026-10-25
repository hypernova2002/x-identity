class Schemas::Me < Schemas::User
  schema(
    required: %w[password_changed_at otp_method passkeys_available account],
    properties: {
      password_changed_at: { type: :string, format: "date-time" },
      otp_method: { type: :string, enum: AuthConfiguration::OTP_METHODS, description: "The method used when setting up MFA." },
      passkeys_available: { type: :boolean, description: "Whether the account lets console users add passkeys." },
      account: Schemas::Account
    }
  )
end
