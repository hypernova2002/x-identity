module V1
  module Accounts
    module Projects
      class OpenidConfigurationsController < BaseController
        def show
          cache_publicly(1.hour)
          issuer = current_project.token_issuer
          render json: {
            issuer: issuer,
            authorization_endpoint: "#{issuer}/oauth2/authorize",
            token_endpoint: "#{issuer}/oauth2/token",
            userinfo_endpoint: "#{issuer}/oauth2/userinfo",
            jwks_uri: "#{issuer}/.well-known/jwks.json",
            revocation_endpoint: "#{issuer}/oauth2/revoke",
            end_session_endpoint: "#{issuer}/oauth2/logout",
            response_types_supported: [ "code" ],
            response_modes_supported: [ "query" ],
            grant_types_supported: %w[authorization_code refresh_token client_credentials],
            subject_types_supported: [ "public" ],
            id_token_signing_alg_values_supported: [ current_project.auth_configuration!.signing_algorithm ],
            scopes_supported: ::Oidc::Authorization::SUPPORTED_SCOPES,
            claims_supported: %w[sub iss aud exp iat auth_time nonce amr email email_verified name custom_attributes groups],
            token_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post none],
            revocation_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post none],
            code_challenge_methods_supported: [ "S256" ],
            prompt_values_supported: %w[none login],
            authorization_response_iss_parameter_supported: true
          }
        end
      end
    end
  end
end
