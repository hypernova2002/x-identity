module ApiGrants
  class UpdateRequest < ApplicationRequestModel
    attribute :scopes, Fields::Scopes
  end
end
