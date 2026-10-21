class Schemas::EndUser
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid email status email_verified mfa_enabled invitation_pending custom_attributes created_at updated_at],
    properties: {
      uid: { type: :string, example: "eu_8Jd2Kq9LmP3xR5tN7vB4cZ6w", description: "The `sub` claim in this end user's tokens." },
      email: { type: :string, format: :email },
      name: { type: [ :string, :null ] },
      status: { type: :string, enum: EndUser.statuses.keys },
      email_verified: { type: :boolean },
      mfa_enabled: { type: :boolean },
      invitation_pending: { type: :boolean, description: "Created by an admin and hasn't set a password yet." },
      custom_attributes: { type: :object, description: "Values for the project's custom attributes, keyed by attribute key." },
      last_sign_in_at: { type: [ :string, :null ], format: "date-time" },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
