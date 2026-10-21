module V1
  module Accounts
    module Projects
      class EndUsersController < ManagementController
        FILTERS = %i[email_cont name_cont status_eq].freeze

        before_action :set_end_user, only: %i[show update destroy reset_mfa sign_out resend_invitation]

        def index
          end_users = current_project.end_users.ransack(params.fetch(:q, {}).permit(*FILTERS)).result
          end_users = paginated(end_users.includes(:otp_credential).order(:created_at, :id))
          render json: EndUserSerializer.new(end_users).serializable_hash
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
