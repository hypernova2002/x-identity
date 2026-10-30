module EndUserAuth
  class ResendConfirmationRequest < ClientRequest
    attribute :email, SignInFields::SignInEmail
  end
end
