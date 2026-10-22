module IdentityProviders
  # One of the two: the IdP's metadata document, or the URL it's published at.
  class ParseSamlMetadataRequest < ApplicationRequestModel
    attribute? :metadata_xml, RequestTypes::T::String.constrained(min_size: 1, max_size: 256_000)
    attribute? :metadata_url, RequestTypes::T::String.constrained(min_size: 1, max_size: 2048)
  end
end
