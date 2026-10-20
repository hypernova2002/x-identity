class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.x.mail_from }
  layout "mailer"

  private

  def console_url(account, path, token)
    "#{Rails.configuration.x.console_base_url}/#{account.slug}/#{path}?#{{ token: token }.to_query}"
  end
end
