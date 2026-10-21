module V1
  module Accounts
    class ProjectsController < AuthenticatedController
      include Paginated

      before_action :set_project, only: %i[show update destroy]

      def index
        projects = paginated(ProjectPolicy::Scope.new(current_user).resolve.order(:created_at, :id))
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

      # Projects the user can't view are reported as missing, so their existence isn't revealed.
      def set_project
        @project = current_account.projects.find_by_uid!(params[:uid])
        raise ActiveRecord::RecordNotFound unless ProjectPolicy.new(current_user, @project).view?
      end
    end
  end
end
