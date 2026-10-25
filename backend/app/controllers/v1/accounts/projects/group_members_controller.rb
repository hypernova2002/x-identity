module V1
  module Accounts
    module Projects
      class GroupMembersController < ConsoleController
        before_action :set_group

        def index
          members = paginated(@group.end_users.includes(:otp_credential, :identities, :groups).order(:email, :id))
          render json: EndUserSerializer.new(members).serializable_hash
        end

        def create
          end_user = current_project.end_users.find_by_uid!(parse_request(::Groups::AddMemberRequest).end_user_uid)
          management.add_member(@group, end_user)
          head :no_content
        end

        def destroy
          management.remove_member(@group, current_project.end_users.find_by_uid!(params[:uid]))
          head :no_content
        end

        private

        def set_group
          @group = current_project.groups.find_by_uid!(params[:group_uid])
        end

        def management
          ::Groups::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
