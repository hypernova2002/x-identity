# Absolute URLs that browsers are sent to or post to: https, or http on the loopback interface for
# local development. No fragments.
module WebUrl
  LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1].freeze
  MAX_LENGTH = 2048

  # @param value [Object]
  # @return [Boolean]
  def self.valid?(value)
    return false unless value.is_a?(String) && value.length <= MAX_LENGTH

    uri = URI.parse(value)
    return false if uri.fragment || uri.host.blank?

    uri.scheme == "https" || (uri.scheme == "http" && LOOPBACK_HOSTS.include?(uri.hostname))
  rescue URI::InvalidURIError
    false
  end
end
