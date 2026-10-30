module EndUserAuth
  class SignUpRequest < ClientRequest
    attribute :email, RequestTypes::Email
    attribute :password, SignInFields::NewPassword
    attribute? :name, RequestTypes::Name.meta(description: "The end user's name.")
    attribute? :custom_attributes, RequestTypes::CustomAttributes
  end
end
