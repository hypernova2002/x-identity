module EndUsers
  # Field types shared by the end user requests.
  module Fields
    Name = RequestTypes::Name.optional.meta(description: "The end user's name; null removes it.")
  end
end
