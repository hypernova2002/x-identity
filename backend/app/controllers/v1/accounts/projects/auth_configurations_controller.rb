module V1
  module Accounts
    module Projects
      class AuthConfigurationsController < ManagementController
        def show
          authorize_project!(:view?)
          render json: AuthConfigurationSerializer.new(current_project.auth_configuration!).serializable_hash
        end

        def update
          configuration = ::AuthConfigurations::Update.new(actor: current_user, owner: current_project, **client_info)
            .call(parse_request(::AuthConfigurations::UpdateRequest).to_h)
          render json: AuthConfigurationSerializer.new(configuration).serializable_hash
        end
      end
    end
  end
end
