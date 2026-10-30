module Projects
  class UpdateRequest < ApplicationRequestModel
    UrlTemplate = RequestTypes::Url.optional
      .meta(description: "An https URL containing {token}, used for links in end-user emails. null removes the link.")

    attribute? :name, RequestTypes::Name.meta(description: "The project's name.")
    attribute? :allow_self_sign_up, RequestTypes::T::Bool.meta(description: "End users can create their own accounts.")
    attribute? :confirm_sign_up_url, UrlTemplate
    attribute? :reset_password_url, UrlTemplate
    attribute? :accept_invitation_url, UrlTemplate
  end
end
