module V1
  module Accounts
    class InvitationsController < AuthenticatedController
      include Listing

      LIST = ListQuery.new(
        search: "email_i_cont",
        filters: %i[role_eq],
        sorts: { "email" => :email, "role" => :role, "expires_at" => :expires_at, "created_at" => :created_at },
        default_sort: "created_at"
      )

      before_action :require_account_admin!

      def index
        invitations = listed(current_account.invitations.pending.includes(:invited_by), LIST)
        render json: InvitationSerializer.new(invitations).serializable_hash
      end

      def create
        invitation = ::Invitations::Create.new(inviter: current_user, **client_info)
          .call(**parse_request(::Invitations::CreateRequest).to_h)
        render json: InvitationSerializer.new(invitation).serializable_hash, status: :created
      end

      def destroy
        invitation = current_account.invitations.pending.find_by_uid!(params[:uid])
        invitation.revoke!
        current_account.realm.recorder(**client_info)
          .record(action: "invitation.revoked", actor: current_user, target: invitation)
        head :no_content
      end
    end
  end
end
