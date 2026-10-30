module EndUserAuth
  class SignOutRequest < ClientRequest
    attribute :refresh_token, SignInFields::RefreshToken
  end
end
