class Schemas::Me < Schemas::User
  schema(
    required: %w[password_changed_at account],
    properties: {
      password_changed_at: { type: :string, format: "date-time" },
      account: Schemas::Account
    }
  )
end
