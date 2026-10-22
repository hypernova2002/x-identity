module Groups
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name
    attribute? :description, RequestTypes::T::String.constrained(max_size: 500).optional
    attribute? :default_for_new_users, RequestTypes::T::Bool.meta(description: "New end users join the group automatically.")
  end
end
