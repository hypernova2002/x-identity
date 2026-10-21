module EndUserAuth
  # Send email and code, or the token from the email's link.
  class ConfirmSignUpRequest < ClientRequest
    attribute? :email, RequestTypes::EmailLookup
    attribute? :code, RequestTypes::EmailCode
    attribute? :token, RequestTypes::Token.meta(description: "From the link in the email, instead of email and code.")
  end
end
