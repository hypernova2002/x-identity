module Auth
  class RefreshRequest < ApplicationRequestModel
    attribute :refresh_token, RequestTypes::Token
  end
end
