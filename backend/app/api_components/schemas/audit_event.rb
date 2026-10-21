class Schemas::AuditEvent
  include OpenapiRuby::Components::Base

  reference = {
    type: :object,
    required: %w[type],
    properties: { type: { type: :string }, uid: { type: [ :string, :null ] }, label: { type: [ :string, :null ] } }
  }

  schema(
    type: :object,
    required: %w[uid action actor metadata occurred_at],
    properties: {
      uid: { type: :string },
      action: { type: :string, example: "user.signed_in" },
      actor: reference,
      target: reference.merge(type: [ :object, :null ]),
      project_uid: { type: [ :string, :null ] },
      app_client_uid: { type: [ :string, :null ], description: "The app client an end user signed in through." },
      ip: { type: [ :string, :null ] },
      user_agent: { type: [ :string, :null ] },
      metadata: { type: :object },
      occurred_at: { type: :string, format: "date-time" }
    }
  )
end
