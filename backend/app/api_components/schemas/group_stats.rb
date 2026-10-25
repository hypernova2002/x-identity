class Schemas::GroupStats
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[total empty],
    properties: {
      total: { type: :integer },
      empty: { type: :integer, description: "Groups with no members." }
    }
  )
end
