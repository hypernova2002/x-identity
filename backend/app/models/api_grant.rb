# The scopes a machine-to-machine app may request in access tokens for one API.
class ApiGrant < ApplicationRecord
  include HasUid

  self.uid_prefix = "grant"

  belongs_to :app_client
  belongs_to :api_resource

  validates :api_resource_id, uniqueness: { scope: :app_client_id, message: :already_granted }
  validate :client_is_a_machine_app_of_the_project
  validate :scopes_are_the_apis

  private

  def client_is_a_machine_app_of_the_project
    errors.add(:app_client, :not_machine_app) unless app_client&.machine?
    errors.add(:api_resource, :other_project) if app_client && api_resource && app_client.project_id != api_resource.project_id
  end

  def scopes_are_the_apis
    return errors.add(:scopes, :invalid_scope_name_list) unless scopes.is_a?(Array) && scopes.all?(String)

    unknown = scopes - api_resource&.scope_names.to_a
    errors.add(:scopes, :undefined_scopes, scopes: unknown) if unknown.any?
  end
end
