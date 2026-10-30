module Auth
  class SignOutRequest < ApplicationRequestModel
    attribute :refresh_token, SignInFields::RefreshToken
  end
end
