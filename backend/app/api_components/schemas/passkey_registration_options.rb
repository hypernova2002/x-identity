class Schemas::PasskeyRegistrationOptions
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[registration_id public_key],
    properties: {
      registration_id: { type: :string, description: "Send back with the new passkey. Valid for 5 minutes, once." },
      public_key: { type: :object, description: "PublicKeyCredentialCreationOptions, as JSON, for navigator.credentials.create." }
    }
  )
end
