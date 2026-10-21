module Projects
  class CreateRequest < ApplicationRequestModel
    attribute :name, RequestTypes::Name
  end
end
