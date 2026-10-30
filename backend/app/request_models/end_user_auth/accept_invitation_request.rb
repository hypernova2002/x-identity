module EndUserAuth
  # Send email and code, or the token from the invitation's link, with the first password.
  class AcceptInvitationRequest < ClientRequest
    attribute :password, SignInFields::NewPassword
    attribute? :email, SignInFields::EmailLinkEmail
    attribute? :code, SignInFields::EmailLinkCode
    attribute? :token, RequestTypes::Token.meta(description: "From the link in the invitation, instead of email and code.")
  end
end
