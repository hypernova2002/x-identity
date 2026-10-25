module V1
  module Accounts
    module Projects
      class MeController < SignedInEndUserController
        def show
          render json: EndUserSerializer.new(current_user).serializable_hash
        end

        def update
          end_user = ::EndUsers::Profile.new(end_user: current_user, **client_info)
            .update(**parse_request(::EndUserMe::UpdateRequest).to_h)
          render json: EndUserSerializer.new(end_user).serializable_hash
        end
      end
    end
  end
end
