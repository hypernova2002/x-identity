module EndUserAuth
  class SignOutRequest < ClientRequest
    attribute :refresh_token, RequestTypes::Token
  end
end
