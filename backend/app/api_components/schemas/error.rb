class Schemas::Error
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    description: "Standard error response. Codes and their HTTP statuses:\n\n" +
      ErrorCodes::REGISTRY.map { |code, definition| "- `#{code}` (#{definition[:status]}): #{definition[:default_message]}" }.join("\n"),
    required: %w[error],
    properties: {
      error: {
        type: :object,
        required: %w[code message details],
        properties: {
          code: { type: :string, enum: ErrorCodes::REGISTRY.keys.map(&:to_s) },
          message: { type: :string },
          details: {
            type: :array,
            items: {
              type: :object,
              required: %w[field message],
              properties: {
                field: { type: :string },
                message: { type: :string }
              }
            }
          }
        }
      }
    }
  )
end
