module EndUsers
  class CreateRequest < ApplicationRequestModel
    attribute :email, RequestTypes::Email.meta(description: "The end user's email address.")
    attribute? :name, Fields::Name
    attribute? :custom_attributes, RequestTypes::CustomAttributes
    attribute? :send_invitation, RequestTypes::T::Bool.meta(description: "Email an invitation to set a password. Defaults to true.")
  end
end
