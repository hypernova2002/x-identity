require "net/smtp"

# Base for jobs that look up a user and email them a one-time link. Doing the lookup in a job keeps
# the HTTP response identical, in content and timing, whether or not the email belongs to a user.
# Tokens are generated inside the job so plaintext tokens never sit in the queue.
class TransactionalEmailJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, Net::SMTPServerBusy, Errno::ECONNREFUSED,
    wait: :polynomially_longer, attempts: 5

  private

  def request_context(ip, user_agent)
    RequestContext.new(ip: ip, user_agent: user_agent)
  end
end
