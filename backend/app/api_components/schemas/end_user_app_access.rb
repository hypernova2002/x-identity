class Schemas::EndUserAppAccess
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[app_type uid name enabled via],
    properties: {
      app_type: { type: :string, enum: %w[app_client saml_app] },
      uid: { type: :string },
      name: { type: :string },
      enabled: { type: :boolean },
      via: {
        type: :array,
        description: "The assignments that give the user access: direct, or through a group.",
        items: {
          type: :object,
          required: %w[type assignment_uid],
          properties: {
            type: { type: :string, enum: %w[direct group] },
            assignment_uid: { type: :string },
            group_uid: { type: :string },
            group_name: { type: :string }
          }
        }
      }
    }
  )
end
