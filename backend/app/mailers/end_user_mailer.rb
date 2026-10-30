# Emails to a project's end users. They name the project, not x-identity's console.
class EndUserMailer < ApplicationMailer
  def confirmation(end_user, code, link)
    assign(end_user, code: code, link: link)
    send_to(end_user)
  end

  def password_reset(end_user, code, link)
    assign(end_user, code: code, link: link)
    send_to(end_user)
  end

  def invitation(end_user, code, link)
    assign(end_user, code: code, link: link)
    send_to(end_user)
  end

  def existing_account(end_user)
    assign(end_user)
    send_to(end_user)
  end

  def email_change_code(end_user, new_email, code)
    assign(end_user, code: code)
    send_to(end_user, to: new_email)
  end

  def disabled_after_mfa_failures(end_user)
    assign(end_user)
    send_to(end_user)
  end

  def new_device_sign_in(end_user, device)
    assign(end_user, link: ProjectEndpoints.preferred(end_user.project).hosted_page("apps"))
    @device = device
    send_to(end_user)
  end

  def email_change_notice(end_user, new_email)
    assign(end_user)
    @new_email = new_email
    send_to(end_user)
  end

  private

  def assign(end_user, code: nil, link: nil)
    @end_user = end_user
    @project = end_user.project
    @code = code
    @link = link
  end

  def send_to(end_user, to: end_user.email)
    localized_mail(end_user.locale, to: to, project: @project.name)
  end
end
