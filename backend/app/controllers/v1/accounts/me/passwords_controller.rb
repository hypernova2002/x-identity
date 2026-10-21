module V1
  module Accounts
    module Me
      class PasswordsController < AuthenticatedController
        def update
          ::Users::PasswordChange.new(user: current_user, **client_info).change!(
            **parse_request(::Me::ChangePasswordRequest).to_h,
            keep_family_id: current_session_id
          )
          head :no_content
        end
      end
    end
  end
end
