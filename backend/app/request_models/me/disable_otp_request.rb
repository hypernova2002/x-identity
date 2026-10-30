module Me
  class DisableOtpRequest < ApplicationRequestModel
    attribute :current_password, RequestTypes::Password.meta(description: "The user's current password.")
    attribute :code, RequestTypes::OtpCode
  end
end
