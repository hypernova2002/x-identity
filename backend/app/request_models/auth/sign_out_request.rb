module Auth
  class SignOutRequest < ApplicationRequestModel
    attribute :refresh_token, RequestTypes::Token
  end
end
