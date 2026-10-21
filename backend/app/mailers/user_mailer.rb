class UserMailer < ApplicationMailer
  def email_verification(user, token)
    @user = user
    @url = console_url(user.account, "verify-email", token)
    mail(to: user.email, subject: "Verify your email address")
  end

  def password_reset(user, token)
    @user = user
    @url = console_url(user.account, "reset-password", token)
    mail(to: user.email, subject: "Reset your password")
  end

  def email_change_confirmation(user, new_email, token)
    @user = user
    @url = console_url(user.account, "confirm-email-change", token)
    mail(to: new_email, subject: "Confirm your new email address")
  end

  def disabled_after_mfa_failures(user)
    @user = user
    mail(to: user.email, subject: "Your x-identity user has been disabled")
  end

  def email_change_notice(user, new_email)
    @user = user
    @new_email = new_email
    mail(to: user.email, subject: "Your email address is being changed")
  end
end
