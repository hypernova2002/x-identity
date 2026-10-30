module Auth
  class RefreshRequest < ApplicationRequestModel
    attribute :refresh_token, SignInFields::RefreshToken
  end
end
