module V1
  module Accounts
    module Projects
      # The app portal: its own OpenID Connect client settings, and the apps a signed-in user can open.
      class PortalController < EndUserController
        skip_before_action :authenticate_user!, only: :show

        def show
          client = current_project.portal_client!
          render json: {
            issuer: current_endpoints.issuer,
            client_id: client.uid,
            redirect_uri: current_endpoints.hosted_page("apps"),
            post_logout_redirect_uri: current_endpoints.hosted_page("signed-out")
          }
        end

        def apps
          assignments = AppAssignment.where(project: current_project, principal: current_user)
            .or(AppAssignment.where(project: current_project, principal_type: "Group", principal_id: current_user.group_memberships.select(:group_id)))
          clients = current_project.app_clients.managed.enabled.where.not(launch_url: nil).where(id: assignments.where(app_type: "AppClient").select(:app_id))
          saml_apps = current_project.saml_apps.enabled.where(id: assignments.where(app_type: "SamlApp").select(:app_id))

          apps = clients.map { |client| { uid: client.uid, kind: "oidc", name: client.name, launch_url: client.launch_url } } +
            saml_apps.map { |app| { uid: app.uid, kind: "saml", name: app.name, launch_url: current_endpoints.url("/saml/apps/#{app.uid}/launch") } }
          render json: apps.sort_by { |app| [ app[:name].downcase, app[:uid] ] }
        end
      end
    end
  end
end
