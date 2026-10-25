class PasskeySerializer
  include Alba::Resource

  attributes :uid, :name, :created_at, :last_used_at
  attribute(:domain, &:rp_id)
  attribute(:synced, &:backup_eligible)
end
