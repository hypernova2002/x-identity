class Schemas::ProjectMember
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[user_uid name email role created_at],
    properties: {
      user_uid: { type: :string },
      name: { type: :string },
      email: { type: :string, format: :email },
      role: { type: :string, enum: ProjectMembership.roles.keys },
      created_at: { type: :string, format: "date-time" }
    }
  )
end
