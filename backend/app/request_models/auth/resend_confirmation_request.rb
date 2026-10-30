module Auth
  class ResendConfirmationRequest < ApplicationRequestModel
    attribute :email, SignInFields::SignInEmail
  end
end
