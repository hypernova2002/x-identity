# Checks a newly added domain's DNS until it's verified or {ProjectDomain::VERIFY_FOR} runs out,
# backing off from a minute to an hour between checks.
class DomainVerificationJob < ApplicationJob
  MAX_WAIT = 1.hour

  queue_as :maintenance
  limits_concurrency to: 1, key: ->(arguments) { arguments[:domain_id] }

  def perform(domain_id:)
    domain = ProjectDomain.status_pending.find_by(id: domain_id)
    return unless domain

    Domains::Verification.new(domain).call
    self.class.set(wait: wait_after(domain.check_attempts)).perform_later(domain_id: domain.id) if domain.status_pending?
  end

  private

  def wait_after(attempts)
    [ 1.minute * (2**(attempts - 1)), MAX_WAIT ].min
  end
end
