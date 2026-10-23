# An admin-defined profile field for a project's end users. Values live in
# `EndUser#custom_attributes`, keyed by `key`.
class EndUserAttributeDefinition < ApplicationRecord
  include HasUid

  self.uid_prefix = "attr"

  def self.ransackable_attributes(_auth_object = nil)
    %w[key label data_type required user_editable include_in_token]
  end

  MAX_PER_PROJECT = 50
  MAX_STRING_LENGTH = 2048
  RESERVED_KEYS = %w[
    sub uid email email_verified name password status iss aud exp iat auth_time amr sid jti token_use client_id
  ].freeze

  belongs_to :project

  enum :data_type, { string: "string", number: "number", boolean: "boolean", date: "date" }, validate: true, prefix: :type

  validates :key,
    presence: true,
    format: { with: /\A[a-z][a-z0-9_]{0,39}\z/, message: "must start with a letter and use only lowercase letters, numbers and underscores" },
    exclusion: { in: RESERVED_KEYS, message: "is reserved" },
    uniqueness: { scope: :project_id }
  validates :label, presence: true, length: { maximum: 100 }
  validates :required, :user_editable, :include_in_token, inclusion: { in: [ true, false ] }
  validates :max_length, numericality: { only_integer: true, in: 1..MAX_STRING_LENGTH }, allow_nil: true
  validate :max_length_only_for_strings
  validate :within_project_limit, on: :create

  private

  def max_length_only_for_strings
    errors.add(:max_length, "only applies to string attributes") if max_length.present? && !type_string?
  end

  def within_project_limit
    return if project.nil? || project.end_user_attribute_definitions.count < MAX_PER_PROJECT

    errors.add(:base, "A project can have at most #{MAX_PER_PROJECT} attributes")
  end
end
