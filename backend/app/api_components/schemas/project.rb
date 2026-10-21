class Schemas::Project
  include OpenapiRuby::Components::Base

  url_template = { type: [ :string, :null ], description: "https URL with {token}, used for links in end-user emails." }

  schema(
    type: :object,
    required: %w[uid name allow_self_sign_up token_issuer created_at updated_at],
    properties: {
      uid: { type: :string, example: "proj_9Fk2Lm8Qw3Rt7Yx5Vb1Nc4D" },
      name: { type: :string },
      allow_self_sign_up: { type: :boolean },
      confirm_sign_up_url: url_template,
      reset_password_url: url_template,
      accept_invitation_url: url_template,
      token_issuer: { type: :string, description: "The `iss` of tokens issued to the project's end users." },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
