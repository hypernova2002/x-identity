module IdentityProviders
  class GroupMappingRequest < ApplicationRequestModel
    attribute :value, RequestTypes::T::String.constrained(min_size: 1, max_size: 255).meta(description: "A group value the provider sends.")
    attribute :group_uid, RequestTypes::Uid.meta(description: "The uid of the project group.")
  end
end
