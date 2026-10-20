module V1
  module Accounts
    class MeController < AuthenticatedController
      def show
        render json: MeSerializer.new(current_user).serializable_hash
      end

      def update
        raise ApiError.from_record(current_user) unless current_user.update(NameRequest.from_params(params).to_h)

        render json: MeSerializer.new(current_user).serializable_hash
      end
    end
  end
end
