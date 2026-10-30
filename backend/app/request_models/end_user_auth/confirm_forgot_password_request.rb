module EndUserAuth
  # Send email and code, or the token from the email's link, with the new password.
  class ConfirmForgotPasswordRequest < ClientRequest
    attribute :password, SignInFields::NewPassword
    attribute? :email, SignInFields::EmailLinkEmail
    attribute? :code, SignInFields::EmailLinkCode
    attribute? :token, SignInFields::EmailLinkToken
  end
end
