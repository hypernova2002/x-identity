module V1
  module Accounts
    class UsersController < AuthenticatedController
      include Paginated

      before_action :require_account_admin!, except: :index
      before_action :set_user, only: %i[show update destroy]

      def index
        users = paginated(current_account.users.includes(:otp_credential).order(:created_at, :id))
        render json: UserSerializer.new(users).serializable_hash
      end

      def show
        render json: UserSerializer.new(@user).serializable_hash
      end

      def update
        user = management.update(@user, **parse_request(::Users::UpdateRequest).to_h)
        render json: UserSerializer.new(user).serializable_hash
      end

      def destroy
        management.destroy(@user)
        head :no_content
      end

      private

      def management
        ::Users::Management.new(actor: current_user, **client_info)
      end

      def set_user
        @user = current_account.users.find_by_uid!(params[:uid])
      end
    end
  end
end
