module Auth
  class ConfirmEmailChangeRequest < ApplicationRequestModel
    attribute :token, RequestTypes::Token.meta(description: "From the link sent to the new address.")
  end
end
