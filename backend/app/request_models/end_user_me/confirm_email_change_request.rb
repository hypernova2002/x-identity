module EndUserMe
  class ConfirmEmailChangeRequest < ApplicationRequestModel
    attribute :code, RequestTypes::EmailCode.meta(description: "The 6-digit code sent to the new address.")
  end
end
