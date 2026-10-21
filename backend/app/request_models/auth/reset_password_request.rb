module Auth
  class ResetPasswordRequest < ApplicationRequestModel
    attribute :token, RequestTypes::Token
    attribute :password, RequestTypes::Password
  end
end
