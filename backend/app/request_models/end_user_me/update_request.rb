module EndUserMe
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name.optional.meta(description: "The end user's name; null removes it.")
    attribute? :locale, RequestTypes::Locale
    attribute? :custom_attributes, RequestTypes::CustomAttributes.meta(description: "Values for the project's user-editable custom attributes, keyed by attribute key.")
  end
end
