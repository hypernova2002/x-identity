module SamlApps
  # One of the two: the metadata document, or the URL it's published at.
  class ParseMetadataRequest < ApplicationRequestModel
    attribute? :metadata_xml, Fields::MetadataXml
    attribute? :metadata_url, Fields::MetadataUrl
  end
end
