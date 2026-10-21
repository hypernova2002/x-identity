class ProjectSerializer
  include Alba::Resource

  attributes :uid, :name, :allow_self_sign_up, :confirm_sign_up_url, :reset_password_url, :accept_invitation_url,
    :created_at, :updated_at

  attribute(:token_issuer, &:token_issuer)
end
