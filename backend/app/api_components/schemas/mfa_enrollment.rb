class Schemas::MfaEnrollment
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[secret provisioning_uri qr_code_svg],
    properties: {
      secret: { type: :string, description: "Base32 TOTP secret for manual entry." },
      provisioning_uri: { type: :string, description: "otpauth:// URI." },
      qr_code_svg: { type: :string, description: "The provisioning URI as an SVG QR code." }
    }
  )
end
