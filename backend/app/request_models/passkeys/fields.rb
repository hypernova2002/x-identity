module Passkeys
  # Field types shared by the passkey requests.
  module Fields
    Name = RequestTypes::T::String.constrained(min_size: 1, max_size: 60).meta(description: "The passkey's name, shown in the user's list of passkeys.")
  end
end
