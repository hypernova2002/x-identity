module V1
  module Accounts
    module Projects
      class EndUsersController < ManagementController
        LIST = ListQuery.new(
          search: "email_or_name_or_uid_i_cont",
          filters: %i[status_eq uid_eq with_verified_email with_mfa invitation_pending in_group],
          sorts: {
            "email" => :email, "name" => :name, "status" => :status, "created_at" => :created_at, "last_sign_in_at" => :last_sign_in_at
          },
          default_sort: "created_at"
        )

        before_action :set_end_user, only: %i[show update destroy reset_mfa sign_out resend_invitation identities unlink_identity access passkeys remove_passkey]

        def index
          end_users = listed(current_project.end_users.includes(:otp_credential, :identities, :groups), LIST, capped: true)
          render json: EndUserSerializer.new(end_users).serializable_hash
        end

        def stats
          render json: ::EndUsers::Stats.new(current_project).call
        end

        def show
          render json: EndUserSerializer.new(@end_user).serializable_hash
        end

        def create
          end_user = management.create(**parse_request(::EndUsers::CreateRequest).to_h)
          render json: EndUserSerializer.new(end_user).serializable_hash, status: :created
        end

        def update
          end_user = management.update(@end_user, **parse_request(::EndUsers::UpdateRequest).to_h)
          render json: EndUserSerializer.new(end_user).serializable_hash
        end

        def destroy
          management.destroy(@end_user)
          head :no_content
        end

        def reset_mfa
          management.reset_mfa(@end_user)
          head :no_content
        end

        def sign_out
          management.sign_out_everywhere(@end_user)
          head :no_content
        end

        def resend_invitation
          management.resend_invitation(@end_user)
          head :accepted
        end

        # The apps the end user can sign in to, and whether directly or through which groups.
        def access
          render json: ::Apps::UserAccess.new(@end_user).call
        end

        def identities
          render json: EndUserIdentitySerializer.new(@end_user.identities.includes(:identity_provider).order(:created_at, :id)).serializable_hash
        end

        def passkeys
          render json: PasskeySerializer.new(@end_user.webauthn_credentials.order(:created_at, :id)).serializable_hash
        end

        def remove_passkey
          management.remove_passkey(@end_user, @end_user.webauthn_credentials.find_by_uid!(params[:passkey_uid]))
          head :no_content
        end

        def unlink_identity
          authorize_project!(:manage_end_users?)
          identity = @end_user.identities.find_by_uid!(params[:identity_uid])
          ::EndUsers::Identities.new(end_user: @end_user, actor: current_user, **client_info).unlink(identity)
          head :no_content
        end

        private

        def set_end_user
          @end_user = current_project.end_users.find_by_uid!(params[:uid])
        end

        def management
          ::EndUsers::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
