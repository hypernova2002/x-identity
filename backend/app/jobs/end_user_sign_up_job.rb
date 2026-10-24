class EndUserSignUpJob < TransactionalEmailJob
  # @param project_id [Integer]
  # @param app_client_id [Integer, nil]
  # @param email [String]
  # @param name [String, nil]
  # @param password_digest [String] already hashed, so no plaintext password is queued
  # @param custom_attributes [Hash]
  # @param ip [String, nil]
  # @param user_agent [String, nil]
  def perform(project_id:, email:, password_digest:, app_client_id: nil, name: nil, custom_attributes: {}, ip: nil, user_agent: nil)
    project = Project.active.find_by(id: project_id)
    return if project.nil?

    EndUsers::SignUp.new(
      project: project,
      app_client: project.app_clients.find_by(id: app_client_id),
      ip: ip, user_agent: user_agent
    ).deliver(email: email, name: name, password_digest: password_digest, custom_attributes: custom_attributes)
  end
end
