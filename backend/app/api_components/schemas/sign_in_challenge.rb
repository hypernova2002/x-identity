class Schemas::SignInChallenge
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[challenge session],
    properties: {
      challenge: { type: :string, enum: Auth::Challenges::ALL },
      session: { type: :string, description: "Pass to respond-to-challenge. Expires after 5 minutes." },
      mfa_methods: {
        type: :array, items: { type: :string, enum: Auth::Challenges::MFA_METHODS },
        description: "For a second-factor challenge (otp or passkey): the methods that can answer it. passkey answers with challenge: passkey."
      },
      recovery_codes: { type: :array, items: { type: :string }, description: "Only after completing MFA setup." }
    }
  )
end
