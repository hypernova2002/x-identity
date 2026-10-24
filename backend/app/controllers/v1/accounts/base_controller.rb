module V1
  module Accounts
    # Loads the account from the URL. Everything under /v1/accounts/:account_uid is scoped to it.
    class BaseController < ApplicationController
      before_action :set_account

      private

      def set_account
        @current_account = Account.find_by_uid!(params[:account_uid])
      end

      # @return [Account]
      def current_account
        @current_account
      end
    end
  end
end
