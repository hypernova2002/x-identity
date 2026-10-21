# Emails to a project's end users. They name the project, not x-identity's console.
class EndUserMailer < ApplicationMailer
  def confirmation(end_user, code, link)
    assign(end_user, code: code, link: link)
    mail(to: end_user.email, subject: "Your #{@project.name} verification code")
  end

  def password_reset(end_user, code, link)
    assign(end_user, code: code, link: link)
    mail(to: end_user.email, subject: "Reset your #{@project.name} password")
  end

  def invitation(end_user, code, link)
    assign(end_user, code: code, link: link)
    mail(to: end_user.email, subject: "You've been invited to #{@project.name}")
  end

  def existing_account(end_user)
    assign(end_user)
    mail(to: end_user.email, subject: "You already have a #{@project.name} account")
  end

  def email_change_code(end_user, new_email, code)
    assign(end_user, code: code)
    mail(to: new_email, subject: "Confirm your new #{@project.name} email address")
  end

  def disabled_after_mfa_failures(end_user)
    assign(end_user)
    mail(to: end_user.email, subject: "Your #{@project.name} account has been disabled")
  end

  def email_change_notice(end_user, new_email)
    assign(end_user)
    @new_email = new_email
    mail(to: end_user.email, subject: "Your #{@project.name} email address is being changed")
  end

  private

  def assign(end_user, code: nil, link: nil)
    @end_user = end_user
    @project = end_user.project
    @code = code
    @link = link
  end
end
