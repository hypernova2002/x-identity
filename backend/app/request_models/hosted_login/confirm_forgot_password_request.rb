module HostedLogin
  class ConfirmForgotPasswordRequest < ApplicationRequestModel
    attribute :email, RequestTypes::EmailLookup.meta(description: "The address the code was sent to.")
    attribute :code, RequestTypes::EmailCode
    attribute :password, SignInFields::NewPassword
  end
end
