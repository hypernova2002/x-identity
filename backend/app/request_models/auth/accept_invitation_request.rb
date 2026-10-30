module Auth
  class AcceptInvitationRequest < ApplicationRequestModel
    attribute :token, RequestTypes::Token.meta(description: "From the link in the invitation email.")
    attribute :name, RequestTypes::Name.meta(description: "The new user's name.")
    attribute :password, SignInFields::NewPassword
  end
end
