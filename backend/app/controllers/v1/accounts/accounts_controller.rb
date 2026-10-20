module V1
  module Accounts
    class AccountsController < AuthenticatedController
      before_action :require_account_admin!, only: :update

      def show
        render json: AccountSerializer.new(current_account).serializable_hash
      end

      def update
        previous_name = current_account.name
        raise ApiError.from_record(current_account) unless current_account.update(NameRequest.from_params(params).to_h)

        if current_account.name != previous_name
          AuditEvents::Recorder.new(account: current_account).record(
            action: "account.updated", actor: current_user, target: current_account, metadata: { from: previous_name, to: current_account.name }
          )
        end
        render json: AccountSerializer.new(current_account).serializable_hash
      end
    end
  end
end
