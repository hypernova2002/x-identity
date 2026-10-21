module EndUserAuth
  # Send email and code, or the token from the invitation's link, with the first password.
  class AcceptInvitationRequest < ClientRequest
    attribute :password, RequestTypes::Password
    attribute? :email, RequestTypes::EmailLookup
    attribute? :code, RequestTypes::EmailCode
    attribute? :token, RequestTypes::Token.meta(description: "From the link in the invitation, instead of email and code.")
  end
end
