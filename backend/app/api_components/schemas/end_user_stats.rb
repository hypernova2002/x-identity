class Schemas::EndUserStats
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[total active disabled invitation_pending signed_in_recently],
    properties: {
      total: { type: :integer },
      active: { type: :integer },
      disabled: { type: :integer },
      invitation_pending: { type: :integer, description: "Created or invited, without a password or linked identity yet." },
      signed_in_recently: { type: :integer, description: "Signed in during the last 30 days." }
    },
    description: "Counts are cached for up to a minute."
  )
end
