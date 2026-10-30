module EndUserAuth
  # Send email and code, or the token from the email's link.
  class ConfirmSignUpRequest < ClientRequest
    attribute? :email, SignInFields::EmailLinkEmail
    attribute? :code, SignInFields::EmailLinkCode
    attribute? :token, SignInFields::EmailLinkToken
  end
end
