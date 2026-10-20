module V1
  module Accounts
    class AuthenticatedController < BaseController
      include Authentication

      private

      # @raise [ApiError] `forbidden`
      def require_account_admin!
        raise ApiError.new(:forbidden) unless AccountPolicy.new(current_user).manage?
      end
    end
  end
end
