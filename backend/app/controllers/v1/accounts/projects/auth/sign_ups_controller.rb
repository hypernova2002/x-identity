module V1
  module Accounts
    module Projects
      module Auth
        class SignUpsController < BaseController
          def create
            app_client, input = parse_client_request(::EndUserAuth::SignUpRequest)
            ::EndUsers::SignUp.new(project: current_project, app_client: app_client, **client_info).call(**input)
            head :accepted
          end
        end
      end
    end
  end
end
