# Emails a user who signed in from a device and country they haven't used lately, when their
# account's or project's settings allow it.
class NewDeviceEmailJob < TransactionalEmailJob
  # @param device_session_id [Integer]
  def perform(device_session_id:)
    device = DeviceSession.find_by(id: device_session_id)
    user = device&.subject
    return unless user&.active? && user.realm.auth_configuration.notify_new_devices && device.unfamiliar?

    mailer = user.is_a?(EndUser) ? EndUserMailer : UserMailer
    mailer.new_device_sign_in(user, device).deliver_now
    user.realm.recorder.record(
      action: "#{user.realm.event_prefix}.new_device_notified", target: user, metadata: { device: device.uid, device_name: device.device_name }
    )
  end
end
