class TokenSetSerializer
  include Alba::Resource

  attributes :access_token, :refresh_token, :token_type, :expires_in
end
