module ProjectAuthHelpers
  # @return [Hash] path params for a project-scoped endpoint
  def project_path_params(project, **extra)
    { account_uid: project.account.uid, project_uid: project.uid, **extra }
  end

  # The code from the most recent email sent to an address.
  def last_code_sent_to(email)
    mail = ActionMailer::Base.deliveries.reverse.find { |delivery| delivery.to.include?(email) }
    mail&.body&.encoded.to_s[/^\s+(\d{6})\s*$/, 1]
  end
end

RSpec.configure do |config|
  config.include ProjectAuthHelpers
end
