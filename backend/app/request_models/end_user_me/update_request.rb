module EndUserMe
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name.optional
    attribute? :custom_attributes, RequestTypes::CustomAttributes
  end
end
