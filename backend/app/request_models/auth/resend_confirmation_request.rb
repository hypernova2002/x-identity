module Auth
  class ResendConfirmationRequest < ApplicationRequestModel
    attribute :email, RequestTypes::EmailLookup
  end
end
