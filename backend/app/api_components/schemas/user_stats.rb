class Schemas::UserStats
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[total admins pending_invitations],
    properties: {
      total: { type: :integer },
      admins: { type: :integer, description: "Owners and admins." },
      pending_invitations: { type: [ :integer, :null ], description: "Only for account admins; null for others." }
    }
  )
end
