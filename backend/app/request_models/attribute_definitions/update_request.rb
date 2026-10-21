module AttributeDefinitions
  class UpdateRequest < ApplicationRequestModel
    attribute? :label, RequestTypes::Name
    attribute? :required, RequestTypes::T::Bool
    attribute? :max_length, RequestTypes::AttributeMaxLength
    attribute? :user_editable, RequestTypes::T::Bool
    attribute? :include_in_token, RequestTypes::T::Bool
  end
end
