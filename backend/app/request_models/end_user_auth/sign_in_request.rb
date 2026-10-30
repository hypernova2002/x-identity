module EndUserAuth
  class SignInRequest < ClientRequest
    attribute :email, SignInFields::SignInEmail
    attribute :password, SignInFields::SignInPassword
  end
end
