class Schemas::AttributeDefinition
  include OpenapiRuby::Components::Base

  schema(
    type: :object,
    required: %w[uid key label data_type required user_editable include_in_token created_at updated_at],
    properties: {
      uid: { type: :string },
      key: { type: :string },
      label: { type: :string },
      data_type: { type: :string, enum: EndUserAttributeDefinition.data_types.keys },
      required: { type: :boolean },
      max_length: { type: [ :integer, :null ] },
      user_editable: { type: :boolean, description: "Whether end users can set it themselves." },
      include_in_token: { type: :boolean, description: "Whether it's added to the ID token's custom_attributes claim." },
      created_at: { type: :string, format: "date-time" },
      updated_at: { type: :string, format: "date-time" }
    }
  )
end
