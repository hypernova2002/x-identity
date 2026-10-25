module V1
  module Accounts
    module Projects
      module Me
        class IdentitiesController < SignedInEndUserController
          def index
            render json: EndUserIdentitySerializer.new(current_user.identities.includes(:identity_provider).order(:created_at, :id)).serializable_hash
          end

          def destroy
            identity = current_user.identities.find_by_uid!(params[:uid])
            ::EndUsers::Identities.new(end_user: current_user, actor: current_user, **client_info).unlink(identity)
            head :no_content
          end
        end
      end
    end
  end
end
