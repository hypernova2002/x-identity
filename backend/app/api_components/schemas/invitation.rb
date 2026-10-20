class Schemas::Invitation
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid email role expires_at created_at],
    properties: {
      uid: { type: :string },
      email: { type: :string, format: :email },
      role: { type: :string, enum: Invitation.roles.keys },
      invited_by_uid: { type: [ :string, :null ] },
      expires_at: { type: :string, format: "date-time" },
      created_at: { type: :string, format: "date-time" }
    }
  )
end
