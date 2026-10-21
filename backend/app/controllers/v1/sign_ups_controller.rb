module V1
  class SignUpsController < ApplicationController
    def create
      result = ::Accounts::SignUp.new(**client_info).call(**parse_request(::SignUps::CreateRequest).to_h)

      render json: { account: AccountSerializer.new(result.account).serializable_hash, user: UserSerializer.new(result.user).serializable_hash },
        status: :created
    end
  end
end
