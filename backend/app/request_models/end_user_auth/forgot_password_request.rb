module EndUserAuth
  class ForgotPasswordRequest < ClientRequest
    attribute :email, SignInFields::SignInEmail
  end
end
