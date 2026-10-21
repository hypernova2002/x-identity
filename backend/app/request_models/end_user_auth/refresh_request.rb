module EndUserAuth
  class RefreshRequest < ClientRequest
    attribute :refresh_token, RequestTypes::Token
  end
end
