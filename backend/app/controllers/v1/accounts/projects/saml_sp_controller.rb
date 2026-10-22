module V1
  module Accounts
    module Projects
      # The project as a SAML service provider for one upstream provider: its metadata, the assertion
      # consumer service, and single logout with the provider.
      class SamlSpController < BaseController
        include SsoSessionCookie

        before_action :set_provider

        def metadata
          render xml: ::SamlSp::Metadata.new(@provider).to_xml
        end

        def acs
          form = request.request_parameters
          url = ::IdentityProviders::BrowserSignIn.new(project: current_project, **client_info).saml_callback(
            provider: @provider, saml_response: string(form["SAMLResponse"]), relay_state: string(form["RelayState"])
          )
          redirect_to url, allow_other_host: true, status: :see_other
        rescue ApiError => error
          redirect_to ::Oidc::Urls.hosted_page(current_project, "error", error: error.code, error_description: error.message), allow_other_host: true, status: :see_other
        end

        def slo
          source = request.post? ? request.request_parameters : request.query_parameters
          saml = source.slice("SAMLRequest", "SAMLResponse", "RelayState").select { |_name, value| value.is_a?(String) }
          url = ::SamlIdp::Logout.new(project: current_project, **client_info).receive_upstream(
            provider: @provider, params: saml, raw_query: request.query_string, binding: request.post? ? :post : :redirect, session_token: session_token
          )
          clear_session if saml["SAMLRequest"].present?
          redirect_to url, allow_other_host: true, status: :see_other
        end

        private

        def set_provider
          @provider = current_project.identity_providers.kind_saml.find_by_uid!(params[:provider_uid])
        end

        def string(value)
          value if value.is_a?(String)
        end
      end
    end
  end
end
