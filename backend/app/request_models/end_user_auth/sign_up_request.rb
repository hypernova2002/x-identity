module EndUserAuth
  class SignUpRequest < ClientRequest
    attribute :email, RequestTypes::Email
    attribute :password, RequestTypes::Password
    attribute? :name, RequestTypes::Name
    attribute? :custom_attributes, RequestTypes::CustomAttributes
  end
end
