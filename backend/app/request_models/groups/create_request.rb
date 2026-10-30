module Groups
  class CreateRequest < ApplicationRequestModel
    attribute :name, Fields::Name
    attribute? :description, Fields::Description
    attribute? :default_for_new_users, Fields::DefaultForNewUsers
  end
end
