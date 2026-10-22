require "resolv"

module IdentityProviders
  # JSON requests to identity providers. Only https is allowed, and hosts resolving to private,
  # loopback or link-local addresses are refused, so provider URLs entered by admins can't be used
  # to reach internal services. The connection goes to the address that was checked.
  class HttpClient
    Error = Class.new(StandardError)

    TIMEOUT_SECONDS = 5
    MAX_BODY_BYTES = 1.megabyte

    # @param url [String]
    # @return [Hash]
    # @raise [Error]
    def get_json(url)
      uri = parse(url)
      perform(uri, Net::HTTP::Get.new(uri, "Accept" => "application/json"))
    end

    # @param url [String]
    # @return [String] the body, e.g. a SAML metadata document
    # @raise [Error]
    def get_text(url)
      uri = parse(url)
      perform(uri, Net::HTTP::Get.new(uri, "Accept" => "application/samlmetadata+xml, application/xml, text/xml"), parse_json: false)
    end

    # @param url [String]
    # @param form [Hash{String => String}]
    # @param basic_auth [Array(String, String), nil] client id and secret, for client_secret_basic
    # @return [Hash]
    # @raise [Error] including when the provider answers with an OAuth error
    def post_form(url, form, basic_auth: nil)
      uri = parse(url)
      request = Net::HTTP::Post.new(uri, "Accept" => "application/json")
      request.set_form_data(form)
      request.basic_auth(*basic_auth) if basic_auth
      perform(uri, request)
    end

    private

    def parse(url)
      uri = URI.parse(url.to_s)
      raise Error, "#{url} must be an https URL" unless uri.is_a?(URI::HTTPS) && uri.host.present?

      uri
    rescue URI::InvalidURIError
      raise Error, "#{url} isn't a valid URL"
    end

    def perform(uri, request, parse_json: true)
      http = Net::HTTP.new(uri.host, uri.port)
      http.ipaddr = public_address(uri.host)
      http.use_ssl = true
      http.open_timeout = http.read_timeout = http.write_timeout = TIMEOUT_SECONDS

      response = http.request(request)
      body = response.body.to_s
      raise Error, "#{uri.host} sent a response that is too large" if body.bytesize > MAX_BODY_BYTES
      unless parse_json
        raise Error, "#{uri.host} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        return body
      end

      json = JSON.parse(body)
      raise Error, oauth_error(uri, response, json) unless response.is_a?(Net::HTTPSuccess) && json.is_a?(Hash)

      json
    rescue JSON::ParserError
      raise Error, "#{uri.host} didn't return JSON"
    rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError => error
      raise Error, "couldn't reach #{uri.host} (#{error.class.name.demodulize})"
    end

    def public_address(host)
      addresses = Resolv.getaddresses(host)
      raise Error, "#{host} doesn't resolve" if addresses.empty?

      ips = addresses.map { |address| IPAddr.new(address).then { |ip| ip.ipv4_mapped? ? ip.native : ip } }
      if ips.any? { |ip| ip.private? || ip.loopback? || ip.link_local? || ip.to_i.zero? }
        raise Error, "#{host} resolves to a private address"
      end

      ips.first.to_s
    end

    def oauth_error(uri, response, json)
      code = json["error"] if json.is_a?(Hash)
      "#{uri.host} answered #{response.code}#{" (#{code})" if code.is_a?(String)}"
    end
  end
end
