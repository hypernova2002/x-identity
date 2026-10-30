class UserMailer < ApplicationMailer
  def email_verification(user, token)
    @user = user
    @url = console_url(user.account, "verify-email", token)
    localized_mail(user.locale, to: user.email)
  end

  def password_reset(user, token)
    @user = user
    @url = console_url(user.account, "reset-password", token)
    localized_mail(user.locale, to: user.email)
  end

  def email_change_confirmation(user, new_email, token)
    @user = user
    @url = console_url(user.account, "confirm-email-change", token)
    localized_mail(user.locale, to: new_email)
  end

  def disabled_after_mfa_failures(user)
    @user = user
    localized_mail(user.locale, to: user.email)
  end

  def new_device_sign_in(user, device)
    @user = user
    @device = device
    @url = "#{Rails.configuration.x.console_base_url}/console/security"
    localized_mail(user.locale, to: user.email, account: user.account.name)
  end

  def email_change_notice(user, new_email)
    @user = user
    @new_email = new_email
    localized_mail(user.locale, to: user.email)
  end
end
