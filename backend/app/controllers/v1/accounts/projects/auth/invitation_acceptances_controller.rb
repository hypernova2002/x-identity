module V1
  module Accounts
    module Projects
      module Auth
        class InvitationAcceptancesController < BaseController
          def create
            app_client, input = parse_client_request(::EndUserAuth::AcceptInvitationRequest)
            ::EndUsers::InvitationAcceptance.new(project: current_project, app_client: app_client, **client_info)
              .accept(**input)
            head :no_content
          end
        end
      end
    end
  end
end
