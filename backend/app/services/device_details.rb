# Which request details describe the user's own device. Confidential clients call the API from their
# servers, so for them the IP address and user agent are the server's and aren't recorded.
module DeviceDetails
  # @param app_client [AppClient, nil] nil for the console
  # @param ip [String, nil]
  # @param user_agent [String, nil]
  # @return [Hash{Symbol => String, nil}] `ip` and `user_agent`
  def self.for(app_client, ip:, user_agent:)
    from_device = app_client.nil? || app_client.client_type_public?
    from_device ? { ip: ip, user_agent: user_agent } : { ip: nil, user_agent: nil }
  end
end
