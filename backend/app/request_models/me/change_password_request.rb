module Me
  class ChangePasswordRequest < ApplicationRequestModel
    attribute :current_password, RequestTypes::Password.meta(description: "The user's current password.")
    attribute :new_password, SignInFields::NewPassword
  end
end
