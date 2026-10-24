module ApiResources
  class ScopeRequest < ApplicationRequestModel
    attribute :name, RequestTypes::T::String.constrained(min_size: 1, max_size: 64).meta(description: "e.g. orders:read")
    attribute? :description, RequestTypes::T::String.constrained(max_size: 200).optional
  end
end
