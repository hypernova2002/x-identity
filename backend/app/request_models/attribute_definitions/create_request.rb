module AttributeDefinitions
  class CreateRequest < ApplicationRequestModel
    attribute :key, RequestTypes::T::String.constrained(min_size: 1, max_size: 40, format: /^[a-z][a-z0-9_]*$/)
      .meta(description: "Lowercase letters, numbers and underscores. Can't be changed later.")
    attribute :label, RequestTypes::Name
    attribute :data_type, RequestTypes::T::String.enum(*EndUserAttributeDefinition.data_types.keys).meta(description: "Can't be changed later.")
    attribute? :required, RequestTypes::T::Bool
    attribute? :max_length, RequestTypes::AttributeMaxLength
    attribute? :user_editable, RequestTypes::T::Bool
    attribute? :include_in_token, RequestTypes::T::Bool
  end
end
