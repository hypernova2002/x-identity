module V1
  module Accounts
    module Projects
      module Auth
        # Public end-user auth endpoints. Every request names an enabled app client of the project,
        # with its secret when the client is confidential.
        class BaseController < Projects::BaseController
          private

          # @param request_model_class [Class<EndUserAuth::ClientRequest>]
          # @return [Array(AppClient, Hash)] the authenticated client and the remaining fields
          def parse_client_request(request_model_class)
            input = parse_request(request_model_class).to_h
            app_client = current_project.app_clients.enabled.find_by(uid: input[:client_id])
            raise ApiError.new(:invalid_client) unless app_client&.authenticate(input[:client_secret])

            [ app_client, input.except(:client_id, :client_secret) ]
          end

          def realm
            current_project.realm
          end
        end
      end
    end
  end
end
