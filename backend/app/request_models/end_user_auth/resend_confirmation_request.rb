module EndUserAuth
  class ResendConfirmationRequest < ClientRequest
    attribute :email, RequestTypes::EmailLookup
  end
end
