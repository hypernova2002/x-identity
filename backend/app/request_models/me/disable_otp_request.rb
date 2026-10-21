module Me
  class DisableOtpRequest < ApplicationRequestModel
    attribute :current_password, RequestTypes::Password
    attribute :code, RequestTypes::OtpCode
  end
end
