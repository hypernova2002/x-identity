# An API of the project's own (a resource server) that machine-to-machine apps get access tokens
# for. Its identifier is the tokens' `aud`; its scopes are what apps may be granted on it.
class ApiResource < ApplicationRecord
  include HasUid

  self.uid_prefix = "api"

  MAX_SCOPES = 50
  SCOPE_NAME = %r{\A[A-Za-z0-9_.:/-]{1,64}\z}
  IDENTIFIER = %r{\A[^\s]{3,255}\z}
  ACCESS_TOKEN_TTL_SECONDS = 5.minutes.to_i..AuthConfiguration::MAX_ACCESS_TOKEN_TTL_SECONDS

  belongs_to :project
  has_many :api_grants, dependent: :delete_all

  validates :name, presence: true, length: { maximum: 100 }
  validates :identifier, format: { with: IDENTIFIER, message: :invalid_api_identifier },
    uniqueness: { scope: :project_id }
  validates :access_token_ttl_seconds, numericality: { only_integer: true, in: ACCESS_TOKEN_TTL_SECONDS }, allow_nil: true
  validate :scopes_are_valid

  def self.ransackable_attributes(_auth_object = nil)
    %w[name identifier]
  end

  # @return [Array<String>]
  def scope_names
    scopes.map { |scope| scope["name"] }
  end

  private

  def scopes_are_valid
    unless scopes.is_a?(Array) && scopes.all? { |scope| scope.is_a?(Hash) && scope["name"].is_a?(String) }
      return errors.add(:scopes, :invalid_scope_list)
    end

    errors.add(:scopes, :too_many, count: MAX_SCOPES) if scopes.size > MAX_SCOPES
    errors.add(:scopes, :invalid_scope_names) unless scope_names.all? { |name| name.match?(SCOPE_NAME) }
    errors.add(:scopes, :duplicate_scope_names) unless scope_names.uniq.size == scope_names.size
    errors.add(:scopes, :scope_description_too_long, count: 200) if scopes.any? { |scope| scope["description"].to_s.length > 200 }
  end
end
