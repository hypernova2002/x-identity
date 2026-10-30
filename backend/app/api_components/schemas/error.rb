class Schemas::Error
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    description: "Standard error response. Clients show their own message for `code`, or for `reason` when it's set, and for each " \
      "detail's `code`; `message` is English. Codes and their HTTP statuses:\n\n" +
      ErrorCodes::REGISTRY.map { |code, definition| "- `#{code}` (#{definition[:status]}): #{definition[:default_message]}" }.join("\n"),
    required: %w[error],
    properties: {
      error: {
        type: :object,
        required: %w[code reason message params details],
        properties: {
          code: { type: :string, enum: ErrorCodes::REGISTRY.keys.map(&:to_s) },
          reason: {
            type: [ :string, :null ],
            enum: [ *I18n.t("errors.reasons").keys.map(&:to_s), nil ],
            description: "Which case of the code this is, when the code covers several."
          },
          message: { type: :string },
          params: { type: :object, description: "Values the reason's message refers to, e.g. a group's name." },
          details: {
            type: :array,
            items: {
              type: :object,
              required: %w[field code message params],
              properties: {
                field: { type: :string, description: "The request field, with dots for nested fields, e.g. custom_attributes.plan." },
                code: { type: :string, enum: I18n.t("errors.messages").keys.map(&:to_s) },
                message: { type: :string },
                params: { type: :object, description: "Values the message refers to, e.g. count for too_long, values for inclusion." }
              }
            }
          }
        }
      }
    }
  )
end
