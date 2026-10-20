module V1
  module Accounts
    class ProjectMembersController < AuthenticatedController
      include Paginated

      before_action :set_project
      before_action :set_membership, only: %i[update destroy]

      def index
        memberships = paginated(@project.project_memberships.includes(:user).order(:created_at, :id))
        render json: ProjectMemberSerializer.new(memberships).serializable_hash
      end

      def create
        membership = management.add(**AddProjectMemberRequest.from_params(params).to_h)
        render json: ProjectMemberSerializer.new(membership).serializable_hash, status: :created
      end

      def update
        membership = management.update(@membership, **UpdateProjectMemberRequest.from_params(params).to_h)
        render json: ProjectMemberSerializer.new(membership).serializable_hash
      end

      def destroy
        management.remove(@membership)
        head :no_content
      end

      private

      def set_project
        @project = current_account.projects.find_by_uid!(params[:project_uid])
        raise ActiveRecord::RecordNotFound unless ProjectPolicy.new(current_user, @project).view?
      end

      def set_membership
        @membership = @project.project_memberships.joins(:user).find_by!(users: { uid: params[:user_uid] })
      end

      def management
        ::Projects::MembershipManagement.new(actor: current_user, project: @project)
      end
    end
  end
end
