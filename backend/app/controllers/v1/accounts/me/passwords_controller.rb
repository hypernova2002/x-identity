module V1
  module Accounts
    module Me
      class PasswordsController < AuthenticatedController
        def update
          ::Users::PasswordChange.new(user: current_user).change!(
            **ChangePasswordRequest.from_params(params).to_h,
            keep_family_id: current_session_id
          )
          head :no_content
        end
      end
    end
  end
end
