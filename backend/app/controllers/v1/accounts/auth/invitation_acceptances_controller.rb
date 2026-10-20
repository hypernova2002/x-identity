module V1
  module Accounts
    module Auth
      class InvitationAcceptancesController < BaseController
        def create
          user = ::Invitations::Accept.new(account: current_account).call(**AcceptInvitationRequest.from_params(params).to_h)
          render json: UserSerializer.new(user).serializable_hash, status: :created
        end
      end
    end
  end
end
