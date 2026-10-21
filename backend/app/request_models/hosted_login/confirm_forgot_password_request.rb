module HostedLogin
  class ConfirmForgotPasswordRequest < ApplicationRequestModel
    attribute :email, RequestTypes::EmailLookup
    attribute :code, RequestTypes::EmailCode
    attribute :password, RequestTypes::Password
  end
end
