class EmailChangeRequest < ApplicationRequest
  attribute :new_email, JsonModel::Types::String
  attribute :current_password, JsonModel::Types::String
  attribute? :otp_code, JsonModel::Types::String.meta(description: "Required when MFA is turned on.")
end
