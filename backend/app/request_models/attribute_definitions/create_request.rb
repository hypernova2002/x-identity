module AttributeDefinitions
  class CreateRequest < ApplicationRequestModel
    attribute :key, RequestTypes::T::String.constrained(min_size: 1, max_size: 40, format: /^[a-z][a-z0-9_]*$/)
      .meta(description: "Lowercase letters, numbers and underscores, starting with a letter. Can't be changed later.")
    attribute :label, Fields::Label
    attribute :data_type, RequestTypes::T::String.enum(*EndUserAttributeDefinition.data_types.keys)
      .meta(description: "#{EndUserAttributeDefinition.data_types.keys.join(', ')}. Can't be changed later.")
    attribute? :required, Fields::Required
    attribute? :max_length, Fields::MaxLength
    attribute? :user_editable, Fields::UserEditable
    attribute? :include_in_token, Fields::IncludeInToken
  end
end
