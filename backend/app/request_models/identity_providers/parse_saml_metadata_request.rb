module IdentityProviders
  # One of the two: the IdP's metadata document, or the URL it's published at.
  class ParseSamlMetadataRequest < ApplicationRequestModel
    attribute? :metadata_xml, Fields::MetadataXml
    attribute? :metadata_url, Fields::MetadataUrl
  end
end
