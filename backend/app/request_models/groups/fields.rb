module Groups
  # Field types shared by the group requests.
  module Fields
    T = RequestTypes::T

    Name = RequestTypes::Name.meta(description: "The group's name, unique in the project.")
    Description = T::String.constrained(min_size: 1, max_size: 500).optional.meta(description: "What the group is for; null removes it.")
    DefaultForNewUsers = T::Bool.meta(description: "New end users join the group automatically.")
  end
end
