module V1
  module Accounts
    module Projects
      # Loads the project from the URL. Unknown projects, and projects of other accounts, are 404s.
      class BaseController < Accounts::BaseController
        before_action :set_project

        private

        def set_project
          @project = current_account.projects.find_by_uid!(params[:project_uid])
        end

        def current_project
          @project
        end
      end
    end
  end
end
