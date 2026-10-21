module EndUserAuth
  # Every end-user auth request names the app client it comes from. Confidential clients also send
  # their secret; public clients (browsers, mobile apps) must not have one.
  class ClientRequest < ApplicationRequestModel
    attribute :client_id, RequestTypes::Uid.meta(description: "The app client's uid.")
    attribute? :client_secret, RequestTypes::Token.meta(description: "Confidential clients only.")
  end
end
