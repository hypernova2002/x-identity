module Invitations
  class CreateRequest < ApplicationRequestModel
    attribute :email, RequestTypes::Email.meta(description: "Where the invitation is sent.")
    attribute :role, RequestTypes::AccountRole.meta(description: "The role the user gets on accepting.")
  end
end
