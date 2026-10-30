module Me
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name.meta(description: "The user's name.")
    attribute? :locale, RequestTypes::Locale
  end
end
