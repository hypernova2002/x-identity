module Devices
  # Turns a user agent into a short device label, such as "Chrome on macOS" or "Safari on iPhone".
  # Parsing is local (the device_detector gem); user agents are client-supplied, so labels are hints.
  class Describer
    Description = Data.define(:name, :type)

    HANDHELD = %w[smartphone tablet phablet feature\ phone].freeze

    # @param user_agent [String, nil]
    # @return [Description]
    def call(user_agent)
      return Description.new(name: nil, type: nil) if user_agent.blank?

      detector = DeviceDetector.new(user_agent)
      return Description.new(name: "Automated client", type: "bot") if detector.bot?

      type = detector.device_type
      where = HANDHELD.include?(type) ? detector.device_name.presence || detector.os_name : detector.os_name
      name = [ detector.name, where ].compact_blank.join(" on ").presence
      Description.new(name: name, type: type)
    end
  end
end
