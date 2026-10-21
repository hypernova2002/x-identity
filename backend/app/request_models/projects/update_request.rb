module Projects
  class UpdateRequest < ApplicationRequestModel
    UrlTemplate = RequestTypes::T::String.constrained(min_size: 1, max_size: 2048)
      .meta(description: "An https URL containing {token}, used for links in end-user emails. null removes the link.")

    attribute? :name, RequestTypes::Name
    attribute? :allow_self_sign_up, RequestTypes::T::Bool
    attribute? :confirm_sign_up_url, UrlTemplate.optional
    attribute? :reset_password_url, UrlTemplate.optional
    attribute? :accept_invitation_url, UrlTemplate.optional
  end
end
