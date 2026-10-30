module Auth
  class ForgotPasswordRequest < ApplicationRequestModel
    attribute :email, SignInFields::SignInEmail
  end
end
