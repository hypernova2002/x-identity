module V1
  module Accounts
    module Projects
      module Me
        class EmailChangesController < SignedInEndUserController
          def create
            email_change.request(**parse_request(::Me::EmailChangeRequest).to_h)
            head :accepted
          end

          def confirm
            end_user = email_change.confirm(**parse_request(::EndUserMe::ConfirmEmailChangeRequest).to_h, keep_session_id: current_session_id)
            render json: EndUserSerializer.new(end_user).serializable_hash
          end

          private

          def email_change
            ::EndUsers::EmailChange.new(end_user: current_user, **client_info)
          end
        end
      end
    end
  end
end
