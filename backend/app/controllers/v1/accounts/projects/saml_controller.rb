module V1
  module Accounts
    module Projects
      # A project's SAML 2.0 identity provider: metadata, single sign-on (SP- and IdP-initiated) and
      # single logout. Browsers land on all but the metadata, so problems go to the hosted error page.
      class SamlController < BaseController
        include SsoSessionCookie

        def metadata
          render xml: ::SamlIdp::Metadata.new(current_project, endpoints: current_endpoints).to_xml
        end

        def sso
          deliver ::SamlIdp::SignOn.new(project: current_project, endpoints: current_endpoints, **client_info)
            .sso(params: saml_params, raw_query: request.query_string, binding: binding_used, session_token: session_token)
        end

        def launch
          app = current_project.saml_apps.enabled.find_by_uid!(params[:uid])
          deliver ::SamlIdp::SignOn.new(project: current_project, endpoints: current_endpoints, **client_info).launch(app, session_token: session_token)
        end

        def slo
          url = ::SamlIdp::Logout.new(project: current_project, endpoints: current_endpoints, **client_info)
            .receive(params: saml_params, raw_query: request.query_string, binding: binding_used, session_token: session_token)
          clear_session if params[:SAMLRequest].present?
          redirect_to url, allow_other_host: true, status: :see_other
        end

        private

        def deliver(outcome)
          return render(html: outcome.html.html_safe, content_type: "text/html") if outcome.html

          redirect_to outcome.redirect_url, allow_other_host: true, status: :see_other
        end

        def binding_used
          request.post? ? :post : :redirect
        end

        def saml_params
          source = request.post? ? request.request_parameters : request.query_parameters
          source.slice("SAMLRequest", "SAMLResponse", "RelayState").select { |_name, value| value.is_a?(String) }
        end
      end
    end
  end
end
