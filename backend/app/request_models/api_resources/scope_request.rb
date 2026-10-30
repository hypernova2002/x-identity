module ApiResources
  class ScopeRequest < ApplicationRequestModel
    attribute :name, RequestTypes::ScopeName.meta(description: "Letters, numbers and _ . : / -, e.g. orders:read.")
    attribute? :description, RequestTypes::T::String.constrained(min_size: 1, max_size: 200).optional.meta(description: "What the scope allows.")
  end
end
