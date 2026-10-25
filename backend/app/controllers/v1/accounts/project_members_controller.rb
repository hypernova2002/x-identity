module V1
  module Accounts
    class ProjectMembersController < AuthenticatedController
      include ConsoleProjectScope
      include Listing

      LIST = ListQuery.new(
        search: "user_name_or_user_email_i_cont",
        filters: %i[role_eq],
        sorts: { "name" => "users.name", "email" => "users.email", "role" => :role, "created_at" => :created_at },
        default_sort: "created_at"
      )

      before_action :set_project
      before_action :set_membership, only: %i[update destroy]

      def index
        memberships = listed(@project.project_memberships.joins(:user).includes(:user), LIST)
        render json: ProjectMemberSerializer.new(memberships).serializable_hash
      end

      def create
        membership = management.add(**parse_request(::ProjectMembers::CreateRequest).to_h)
        render json: ProjectMemberSerializer.new(membership).serializable_hash, status: :created
      end

      def update
        membership = management.update(@membership, **parse_request(::ProjectMembers::UpdateRequest).to_h)
        render json: ProjectMemberSerializer.new(membership).serializable_hash
      end

      def destroy
        management.remove(@membership)
        head :no_content
      end

      private

      def set_project
        @project = find_viewable_project!(params[:project_uid])
      end

      def set_membership
        @membership = @project.project_memberships.joins(:user).find_by!(users: { uid: params[:user_uid] })
      end

      def management
        ::Projects::MembershipManagement.new(actor: current_user, project: @project, **client_info)
      end
    end
  end
end
