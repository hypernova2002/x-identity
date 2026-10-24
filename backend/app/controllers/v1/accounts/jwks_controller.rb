module V1
  module Accounts
    class JwksController < BaseController
      # Short enough that clients which don't refetch on an unknown key id pick up a rotated key soon.
      def show
        cache_publicly(5.minutes)
        render json: { keys: current_account.signing_keys.published.order(:activated_at).map(&:jwk) }
      end
    end
  end
end
