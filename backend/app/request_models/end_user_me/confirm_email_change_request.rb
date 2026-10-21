module EndUserMe
  class ConfirmEmailChangeRequest < ApplicationRequestModel
    attribute :code, RequestTypes::EmailCode
  end
end
