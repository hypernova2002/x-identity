module V1
  class AccountLookupsController < ApplicationController
    def show
      account = Account.find_by!(slug: params[:slug].to_s.downcase)
      render json: AccountSummarySerializer.new(account).serializable_hash
    end
  end
end
