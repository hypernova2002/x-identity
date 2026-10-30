module EndUserAuth
  class RefreshRequest < ClientRequest
    attribute :refresh_token, SignInFields::RefreshToken
  end
end
