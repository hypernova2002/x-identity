class Schemas::SamlConnection
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid name on_custom_domain],
    properties: { uid: { type: :string }, name: { type: :string }, on_custom_domain: { type: :boolean } }
  )
end
