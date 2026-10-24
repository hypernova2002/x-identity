class AppClientSecretSerializer
  include Alba::Resource

  attributes :uid, :last_four, :expires_at, :revoked_at, :last_used_at, :created_at
  attribute(:usable) { |secret| secret.revoked_at.nil? && (secret.expires_at.nil? || secret.expires_at.future?) }
end
