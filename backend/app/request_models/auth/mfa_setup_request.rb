module Auth
  class MfaSetupRequest < ApplicationRequestModel
    attribute :session, SignInFields::MfaSetupSession
  end
end
