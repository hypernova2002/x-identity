module Auth
  class MfaSetupRequest < ApplicationRequestModel
    attribute :session, RequestTypes::Token
  end
end
