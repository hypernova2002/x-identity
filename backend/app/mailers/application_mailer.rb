class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.x.mail_from }
  layout "mailer"
  helper_method :greeting

  private

  # Sends the email in the recipient's language, or the current one when they haven't chosen. The
  # subject is the mailer's `subject` message for this email.
  # @param locale [String, nil]
  # @param to [String]
  # @param subject_params [Hash] values the subject refers to
  def localized_mail(locale, to:, **subject_params)
    I18n.with_locale(locale || I18n.locale) do
      mail(to: to, subject: default_i18n_subject(**subject_params))
    end
  end

  def greeting(name)
    name.present? ? t("mailer.greeting", name: name) : t("mailer.greeting_without_name")
  end

  def console_url(account, path, token)
    "#{Rails.configuration.x.console_base_url}/#{account.slug}/#{path}?#{{ token: token }.to_query}"
  end
end
