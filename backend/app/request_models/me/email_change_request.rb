module Me
  class EmailChangeRequest < ApplicationRequestModel
    attribute :new_email, RequestTypes::Email.meta(description: "The new email address. A confirmation link is sent to it.")
    attribute :current_password, RequestTypes::Password.meta(description: "The user's current password.")
    attribute? :otp_code, RequestTypes::OtpCode.meta(description: "Required when MFA is turned on.")
  end
end
