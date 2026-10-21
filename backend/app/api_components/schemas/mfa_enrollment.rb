class Schemas::MfaEnrollment
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[otp_type digits secret provisioning_uri qr_code_svg],
    properties: {
      otp_type: { type: :string, enum: AuthConfiguration::OTP_METHODS },
      digits: { type: :integer, minimum: AuthConfiguration::OTP_DIGITS.min, maximum: AuthConfiguration::OTP_DIGITS.max },
      step_seconds: { type: [ :integer, :null ], description: "TOTP only." },
      secret: { type: :string, description: "Base32 secret for manual entry." },
      provisioning_uri: { type: :string, description: "otpauth:// URI." },
      qr_code_svg: { type: :string, description: "The provisioning URI as an SVG QR code." }
    }
  )
end
