module V1
  module Accounts
    module Projects
      class JwksController < BaseController
        def show
          render json: { keys: current_project.signing_keys.published.order(:activated_at).map(&:jwk) }
        end
      end
    end
  end
end
