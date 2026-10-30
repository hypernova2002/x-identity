module Auth
  class ResetPasswordRequest < ApplicationRequestModel
    attribute :token, RequestTypes::Token.meta(description: "From the link in the password reset email.")
    attribute :password, SignInFields::NewPassword
  end
end
