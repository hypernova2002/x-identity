module Projects
  class CreateRequest < ApplicationRequestModel
    attribute :name, RequestTypes::Name.meta(description: "The project's name.")
  end
end
