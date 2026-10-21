module Auth
  class ConfirmEmailChangeRequest < ApplicationRequestModel
    attribute :token, RequestTypes::Token
  end
end
