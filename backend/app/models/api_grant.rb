# The scopes a machine-to-machine app may request in access tokens for one API.
class ApiGrant < ApplicationRecord
  include HasUid

  self.uid_prefix = "grant"

  belongs_to :app_client
  belongs_to :api_resource

  validates :api_resource_id, uniqueness: { scope: :app_client_id, message: "is already granted to this app" }
  validate :client_is_a_machine_app_of_the_project
  validate :scopes_are_the_apis

  private

  def client_is_a_machine_app_of_the_project
    errors.add(:app_client, "must be a machine-to-machine app") unless app_client&.machine?
    errors.add(:api_resource, "must belong to the same project") if app_client && api_resource && app_client.project_id != api_resource.project_id
  end

  def scopes_are_the_apis
    return errors.add(:scopes, "must be a list of scope names") unless scopes.is_a?(Array) && scopes.all?(String)

    unknown = scopes - api_resource&.scope_names.to_a
    errors.add(:scopes, "aren't defined on the API: #{unknown.join(', ')}") if unknown.any?
  end
end
