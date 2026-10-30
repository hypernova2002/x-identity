module Auth
  class ConfirmEmailRequest < ApplicationRequestModel
    attribute :token, RequestTypes::Token.meta(description: "From the link in the confirmation email.")
  end
end
