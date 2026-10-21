module V1
  module Accounts
    module Projects
      module Oauth2
        # The API behind the hosted login page. Errors use the API's usual format, for the page to show.
        class InteractionsController < Projects::BaseController
          def show
            render json: hosted_login.details
          end

          def sign_in
            render json: hosted_login.sign_in(**parse_request(::HostedLogin::SignInRequest).to_h)
          end

          def respond_to_challenge
            render json: hosted_login.respond_to_challenge(**parse_request(::HostedLogin::ChallengeResponseRequest).to_h)
          end

          def mfa_setup
            enrollment = hosted_login.start_mfa_setup(**parse_request(::HostedLogin::MfaSetupRequest).to_h)
            render json: MfaEnrollmentSerializer.new(enrollment).serializable_hash
          end

          def sign_up
            hosted_login.sign_up(**parse_request(::HostedLogin::SignUpRequest).to_h)
            head :accepted
          end

          def confirm_sign_up
            hosted_login.confirm_sign_up(**parse_request(::HostedLogin::ConfirmSignUpRequest).to_h)
            head :no_content
          end

          def resend_confirmation
            hosted_login.resend_confirmation(**parse_request(::HostedLogin::EmailRequest).to_h)
            head :accepted
          end

          def forgot_password
            hosted_login.forgot_password(**parse_request(::HostedLogin::EmailRequest).to_h)
            head :accepted
          end

          def confirm_forgot_password
            hosted_login.confirm_forgot_password(**parse_request(::HostedLogin::ConfirmForgotPasswordRequest).to_h)
            head :no_content
          end

          # A browser navigation from the page's provider buttons.
          def provider
            redirect_to hosted_login.provider_url(params[:uid]), allow_other_host: true
          rescue ApiError => error
            redirect_to ::Oidc::Urls.hosted_page(current_project, "error", error: error.code, error_description: error.message), allow_other_host: true
          end

          private

          def hosted_login
            ::Oidc::HostedLogin.new(project: current_project, interaction_token: params[:interaction], **client_info)
          end
        end
      end
    end
  end
end
