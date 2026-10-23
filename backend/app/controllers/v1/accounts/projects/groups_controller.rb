module V1
  module Accounts
    module Projects
      class GroupsController < ManagementController
        LIST = ListQuery.new(
          search: "name_i_cont",
          filters: %i[default_for_new_users_eq],
          sorts: {
            "name" => :name,
            "member_count" => "(SELECT COUNT(*) FROM group_memberships WHERE group_memberships.group_id = groups.id)",
            "created_at" => :created_at
          },
          default_sort: "name"
        )

        before_action :set_group, only: %i[show update destroy]

        def index
          groups = listed(current_project.groups, LIST)
          member_counts = GroupMembership.where(group_id: groups.map(&:id)).group(:group_id).count
          render json: GroupSerializer.new(groups, params: { member_counts: member_counts }).serializable_hash
        end

        def show
          render json: GroupSerializer.new(@group).serializable_hash
        end

        def create
          group = management.create(**parse_request(::Groups::CreateRequest).to_h)
          render json: GroupSerializer.new(group).serializable_hash, status: :created
        end

        def update
          group = management.update(@group, **parse_request(::Groups::UpdateRequest).to_h)
          render json: GroupSerializer.new(group).serializable_hash
        end

        def destroy
          management.destroy(@group)
          head :no_content
        end

        private

        def set_group
          @group = current_project.groups.find_by_uid!(params[:uid])
        end

        def management
          ::Groups::Management.new(actor: current_user, project: current_project, **client_info)
        end
      end
    end
  end
end
