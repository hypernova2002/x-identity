module V1
  module Accounts
    module Projects
      module Oauth2
        class UserinfoController < SignedInEndUserController
          def show
            attributes = current_project.end_user_attribute_definitions.where(include_in_token: true).pluck(:key)
            render json: {
              sub: current_user.uid,
              email: current_user.email,
              email_verified: current_user.email_verified?,
              name: current_user.name,
              custom_attributes: current_user.custom_attributes.slice(*attributes),
              groups: (current_user.groups.order(:name).pluck(:name) if @access_token_claims["scope"].to_s.split(" ").include?("groups"))
            }.compact
          end
        end
      end
    end
  end
end
