# Assertion IDs already accepted from an upstream SAML provider, kept until the assertion would have
# expired anyway, so each assertion signs someone in at most once.
class ConsumedSamlAssertion < ApplicationRecord
  belongs_to :identity_provider

  # @param provider [IdentityProvider]
  # @param assertion_id [String]
  # @param expires_at [Time]
  # @return [Boolean] false when the assertion was already used
  def self.consume(provider, assertion_id, expires_at)
    where("expires_at < ?", Time.current).delete_all
    create!(identity_provider: provider, assertion_id: assertion_id, expires_at: expires_at)
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
