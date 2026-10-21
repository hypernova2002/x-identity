module EndUsers
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name.optional
    attribute? :custom_attributes, RequestTypes::CustomAttributes
    attribute? :status, RequestTypes::T::String.enum(*EndUser.statuses.keys)
  end
end
