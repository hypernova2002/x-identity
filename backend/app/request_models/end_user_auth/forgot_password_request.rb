module EndUserAuth
  class ForgotPasswordRequest < ClientRequest
    attribute :email, RequestTypes::EmailLookup
  end
end
