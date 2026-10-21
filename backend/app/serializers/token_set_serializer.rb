class TokenSetSerializer
  include Alba::Resource

  attributes :access_token, :refresh_token, :token_type, :expires_in
  attributes :id_token, if: proc { |token_set| token_set.id_token.present? }
end
