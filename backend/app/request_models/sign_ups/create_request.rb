module SignUps
  class CreateRequest < ApplicationRequestModel
    attribute :account_name, RequestTypes::Name.meta(description: "The new account's name, e.g. the company's.")
    attribute :slug, RequestTypes::T::String.constrained(min_size: 3, max_size: 40, format: /^[A-Za-z0-9-]+$/)
      .meta(description: "Account alias used in sign-in URLs. Letters, numbers and hyphens; stored in lowercase.")
    attribute :name, RequestTypes::Name.meta(description: "The name of the account's owner.")
    attribute :email, RequestTypes::Email.meta(description: "The owner's email address, used to sign in.")
    attribute :password, SignInFields::NewPassword
  end
end
