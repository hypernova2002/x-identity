module SignUps
  class CreateRequest < ApplicationRequestModel
    attribute :account_name, RequestTypes::Name
    attribute :slug, RequestTypes::T::String.constrained(min_size: 3, max_size: 40, format: /^[A-Za-z0-9-]+$/)
      .meta(description: "Account alias used in sign-in URLs.")
    attribute :name, RequestTypes::Name
    attribute :email, RequestTypes::Email
    attribute :password, RequestTypes::Password
  end
end
