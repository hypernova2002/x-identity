module Passkeys
  class RenameRequest < ApplicationRequestModel
    attribute :name, RequestTypes::T::String.constrained(min_size: 1, max_size: 60)
  end
end
