module V1
  module Accounts
    class AuthConfigurationsController < AuthenticatedController
      before_action :require_account_admin!

      def show
        render json: AuthConfigurationSerializer.new(current_account.auth_configuration!).serializable_hash
      end

      def update
        configuration = ::AuthConfigurations::Update.new(actor: current_user, owner: current_account, **client_info)
          .call(parse_request(::AuthConfigurations::UpdateRequest).to_h)
        render json: AuthConfigurationSerializer.new(configuration).serializable_hash
      end
    end
  end
end
