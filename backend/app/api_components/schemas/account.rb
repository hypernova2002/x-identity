class Schemas::Account
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name slug created_at updated_at],
    properties: {
      uid: { type: :string, example: "acct_7Hq2Xf9kLmN3pR8sT4vW6yZa" },
      name: { type: :string },
      slug: { type: :string, description: "Account alias used in sign-in URLs." },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
