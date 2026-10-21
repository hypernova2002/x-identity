module Me
  class EmailChangeRequest < ApplicationRequestModel
    attribute :new_email, RequestTypes::Email
    attribute :current_password, RequestTypes::Password
    attribute? :otp_code, RequestTypes::OtpCode.meta(description: "Required when MFA is turned on.")
  end
end
