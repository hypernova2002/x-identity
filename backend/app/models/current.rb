class Current < ActiveSupport::CurrentAttributes
  attribute :account, :user, :request_context
end
