module Auth
  class ForgotPasswordRequest < ApplicationRequestModel
    attribute :email, RequestTypes::EmailLookup
  end
end
