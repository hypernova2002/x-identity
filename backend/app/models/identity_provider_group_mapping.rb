# Maps a group value an upstream identity provider sends (e.g. "acme-engineering") to a project
# group. Memberships of mapped groups follow the provider at every sign-in.
class IdentityProviderGroupMapping < ApplicationRecord
  belongs_to :identity_provider
  belongs_to :group

  validates :value, presence: true, length: { maximum: 255 }, uniqueness: { scope: %i[identity_provider_id group_id] }
end
