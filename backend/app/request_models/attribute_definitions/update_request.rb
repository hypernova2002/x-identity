module AttributeDefinitions
  class UpdateRequest < ApplicationRequestModel
    attribute? :label, Fields::Label
    attribute? :required, Fields::Required
    attribute? :max_length, Fields::MaxLength
    attribute? :user_editable, Fields::UserEditable
    attribute? :include_in_token, Fields::IncludeInToken
  end
end
