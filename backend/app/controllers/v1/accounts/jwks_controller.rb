module V1
  module Accounts
    class JwksController < BaseController
      def show
        render json: { keys: current_account.signing_keys.published.order(:activated_at).map(&:jwk) }
      end
    end
  end
end
