module EndUsers
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, Fields::Name
    attribute? :custom_attributes, RequestTypes::CustomAttributes
    attribute? :status, RequestTypes::T::String.enum(*EndUser.statuses.keys).meta(description: "Disabled end users can't sign in, and their sessions end.")
  end
end
