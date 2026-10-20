class Schemas::RecoveryCodes
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[recovery_codes],
    properties: {
      recovery_codes: { type: :array, items: { type: :string }, minItems: RecoveryCode::COUNT, maxItems: RecoveryCode::COUNT }
    }
  )
end
