module Me
  class UpdateRequest < ApplicationRequestModel
    attribute? :name, RequestTypes::Name
  end
end
