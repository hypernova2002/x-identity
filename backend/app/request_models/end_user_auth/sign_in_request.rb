module EndUserAuth
  class SignInRequest < ClientRequest
    attribute :email, RequestTypes::EmailLookup
    attribute :password, RequestTypes::Password
  end
end
