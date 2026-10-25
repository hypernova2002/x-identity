module V1
  module Accounts
    module Projects
      class JwksController < PublicController
        # Short enough that clients which don't refetch on an unknown key id pick up a rotated key soon.
        def show
          cache_publicly(5.minutes)
          render json: { keys: current_project.signing_keys.published.order(:activated_at).map(&:jwk) }
        end
      end
    end
  end
end
