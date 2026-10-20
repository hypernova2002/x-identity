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
        project = ::Projects::Management.new(actor: current_user).create(**NameRequest.from_params(params).to_h)
        render json: ProjectSerializer.new(project).serializable_hash, status: :created
      end

      def update
        project = ::Projects::Management.new(actor: current_user).update(@project, **NameRequest.from_params(params).to_h)
        render json: ProjectSerializer.new(project).serializable_hash
      end

      def destroy
        ::Projects::Management.new(actor: current_user).destroy(@project)
        head :no_content
      end

      private

      # Projects the user can't view are reported as missing, so their existence isn't revealed.
      def set_project
        @project = current_account.projects.find_by_uid!(params[:uid])
        raise ActiveRecord::RecordNotFound unless ProjectPolicy.new(current_user, @project).view?
      end
    end
  end
end
