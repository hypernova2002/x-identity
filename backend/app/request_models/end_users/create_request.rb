module EndUsers
  class CreateRequest < ApplicationRequestModel
    attribute :email, RequestTypes::Email
    attribute? :name, RequestTypes::Name.optional
    attribute? :custom_attributes, RequestTypes::CustomAttributes
    attribute? :send_invitation, RequestTypes::T::Bool.meta(description: "Email an invitation to set a password. Defaults to true.")
  end
end
