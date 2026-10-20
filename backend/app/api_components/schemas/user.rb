class Schemas::User
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name email role status email_verified mfa_enabled created_at updated_at],
    properties: {
      uid: { type: :string, example: "usr_3Kd9Wq2LmP7xR5tN8vB4cZ6h" },
      name: { type: :string },
      email: { type: :string, format: :email },
      role: { type: :string, enum: User.roles.keys },
      status: { type: :string, enum: User.statuses.keys },
      email_verified: { type: :boolean },
      mfa_enabled: { type: :boolean },
      last_sign_in_at: { type: [ :string, :null ], format: "date-time" },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
