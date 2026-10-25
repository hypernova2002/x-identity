module V1
  module Accounts
    class ProjectsController < AuthenticatedController
      include ConsoleProjectScope
      include Listing

      LIST = ListQuery.new(
        search: "name_i_cont",
        filters: %i[created_at_gteq created_at_lteq],
        sorts: { "name" => :name, "created_at" => :created_at },
        default_sort: "created_at"
      )

      before_action :set_project, only: %i[show update destroy]

      def index
        projects = listed(ProjectPolicy::Scope.new(current_user).resolve, LIST)
        render json: ProjectSerializer.new(projects).serializable_hash
      end

      def show
        render json: ProjectSerializer.new(@project).serializable_hash
      end

      def create
        project = management.create(**parse_request(::Projects::CreateRequest).to_h)
        render json: ProjectSerializer.new(project).serializable_hash, status: :created
      end

      def update
        project = management.update(@project, **parse_request(::Projects::UpdateRequest).to_h)
        render json: ProjectSerializer.new(project).serializable_hash
      end

      def destroy
        management.destroy(@project)
        head :no_content
      end

      private

      def management
        ::Projects::Management.new(actor: current_user, **client_info)
      end

      def set_project
        @project = find_viewable_project!(params[:uid])
      end
    end
  end
end
