module V1
  module Accounts
    module Projects
      module Oauth2
        class UserinfoController < EndUserController
          def show
            attributes = current_project.end_user_attribute_definitions.where(include_in_token: true).pluck(:key)
            render json: {
              sub: current_user.uid,
              email: current_user.email,
              email_verified: current_user.email_verified?,
              name: current_user.name,
              custom_attributes: current_user.custom_attributes.slice(*attributes)
            }.compact
          end
        end
      end
    end
  end
end
