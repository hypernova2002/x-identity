# A signed-in device: one sign-in in a browser or app, with where and on what it happened. Refresh
# token families and the hosted login browser session that came from the sign-in belong to it, so
# signing the device out revokes them all. Access tokens already issued last until they expire.
class DeviceSession < ApplicationRecord
  include HasUid

  self.uid_prefix = "ses"

  # Activity is recorded at most this often, so refreshing tokens doesn't write on every request.
  ACTIVITY_INTERVAL = 1.minute
  # A device and country used within this long isn't new, so it doesn't trigger a sign-in alert.
  FAMILIAR_FOR = 90.days

  belongs_to :subject, polymorphic: true
  belongs_to :project, optional: true
  has_many :refresh_tokens, dependent: :nullify
  has_many :browser_sessions, dependent: :nullify

  def self.ransackable_attributes(_auth_object = nil)
    %w[device_name last_ip city country_code]
  end

  after_create_commit -> { NewDeviceEmailJob.perform_later(device_session_id: id) }

  # Not signed out, and still holding a refresh token or browser session that works.
  scope :current, lambda {
    where(revoked_at: nil).where(id: RefreshToken.active.select(:device_session_id))
      .or(where(revoked_at: nil).where(id: BrowserSession.active.select(:device_session_id)))
  }

  # @param subject [User, EndUser]
  # @param amr [Array<String>]
  # @param authenticated_at [Time]
  # @param ip [String, nil]
  # @param user_agent [String, nil]
  # @return [DeviceSession]
  def self.start!(subject:, amr:, authenticated_at:, ip:, user_agent:)
    device = Devices::Describer.new.call(user_agent)
    create!(
      subject: subject, project: subject.try(:project), amr: amr, authenticated_at: authenticated_at, last_seen_at: Time.current,
      created_ip: ip, created_user_agent: user_agent, last_ip: ip, last_user_agent: user_agent,
      device_name: device.name, device_type: device.type, **location_for(ip)
    )
  end

  # @param ip [String, nil]
  # @return [Hash{Symbol => String, nil}]
  def self.location_for(ip)
    GeoIp.default.lookup(ip)&.to_h || { city: nil, region: nil, country_code: nil }
  end

  # The device session an access token belongs to, from its `sid` claim: the device session's uid,
  # or, for tokens issued before devices were tracked, a refresh token family.
  # @param sid [String, nil]
  # @return [DeviceSession, nil]
  def self.for_sid(sid)
    return nil if sid.blank?

    find_by(uid: sid) || find_by(id: RefreshToken.where(family_id: sid).select(:device_session_id))
  end

  # Records that the device was used, and where from if that changed.
  # @param ip [String, nil]
  # @param user_agent [String, nil]
  def touch_activity!(ip:, user_agent:)
    return if last_seen_at > ACTIVITY_INTERVAL.ago && ip == last_ip

    changes = { last_seen_at: Time.current, last_user_agent: user_agent.presence || last_user_agent }
    changes.merge!(last_ip: ip, **self.class.location_for(ip)) if ip.present? && ip != last_ip
    update_columns(**changes, updated_at: Time.current)
  end

  # Signs the device out: its refresh tokens and browser session stop working.
  def revoke!
    transaction do
      now = Time.current
      update!(revoked_at: now) unless revoked_at
      refresh_tokens.where(revoked_at: nil).update_all(revoked_at: now)
      browser_sessions.where(revoked_at: nil).update_all(revoked_at: now)
    end
  end

  def revoked?
    revoked_at.present?
  end

  # Whether this sign-in is from somewhere the user hasn't signed in from lately: a device label and
  # country with no other device session in the last 90 days. A user's first sign-in is never
  # unfamiliar. Without a device label, or without a country, only a never-seen label counts, so
  # unparseable user agents and private networks don't alert on every sign-in.
  # @return [Boolean]
  def unfamiliar?
    earlier = subject.device_sessions.where.not(id: id).where(created_at: ...created_at)
    return false if device_name.blank? || !earlier.exists?
    return !earlier.exists?(device_name: device_name) if country_code.blank?

    !earlier.where(created_at: (created_at - FAMILIAR_FOR)..).exists?(device_name: device_name, country_code: country_code)
  end

  # "Dublin, Leinster, IE", or nil when the location is unknown.
  # @return [String, nil]
  def location_label
    [ city, region, country_code ].compact_blank.uniq.join(", ").presence
  end
end
