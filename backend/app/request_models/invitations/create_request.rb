module Invitations
  class CreateRequest < ApplicationRequestModel
    attribute :email, RequestTypes::Email
    attribute :role, RequestTypes::AccountRole
  end
end
