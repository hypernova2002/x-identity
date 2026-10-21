module Auth
  class ConfirmEmailRequest < ApplicationRequestModel
    attribute :token, RequestTypes::Token
  end
end
