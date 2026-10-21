module Me
  class ChangePasswordRequest < ApplicationRequestModel
    attribute :current_password, RequestTypes::Password
    attribute :new_password, RequestTypes::Password
  end
end
