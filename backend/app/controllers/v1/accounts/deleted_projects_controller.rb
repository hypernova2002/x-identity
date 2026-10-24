module V1
  module Accounts
    # Projects deleted within the restore period, for account admins to bring back.
    class DeletedProjectsController < AuthenticatedController
      before_action :require_account_admin!

      def index
        render json: DeletedProjectSerializer.new(current_account.deleted_projects.order(deleted_at: :desc, id: :desc)).serializable_hash
      end

      def restore
        project = current_account.deleted_projects.find_by_uid!(params[:uid])
        ::Projects::Management.new(actor: current_user, **client_info).restore(project)
        render json: ProjectSerializer.new(project).serializable_hash
      end
    end
  end
end
