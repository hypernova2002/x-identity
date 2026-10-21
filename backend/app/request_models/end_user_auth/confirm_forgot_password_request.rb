module EndUserAuth
  # Send email and code, or the token from the email's link, with the new password.
  class ConfirmForgotPasswordRequest < ClientRequest
    attribute :password, RequestTypes::Password
    attribute? :email, RequestTypes::EmailLookup
    attribute? :code, RequestTypes::EmailCode
    attribute? :token, RequestTypes::Token.meta(description: "From the link in the email, instead of email and code.")
  end
end
