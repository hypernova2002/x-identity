require "resolv"

module Domains
  # The DNS lookups domain verification needs. Failed lookups read as no records.
  class DnsResolver
    TIMEOUT_SECONDS = 3

    # @param name [String]
    # @return [Array<String>]
    def txt(name)
      lookup { |dns| dns.getresources(name, Resolv::DNS::Resource::IN::TXT).map { |record| record.strings.join } }
    end

    # @param name [String]
    # @return [String, nil] the target, lower-case, without the trailing dot
    def cname(name)
      lookup { |dns| dns.getresources(name, Resolv::DNS::Resource::IN::CNAME).first&.name&.to_s&.downcase&.chomp(".") }
    end

    private

    def lookup
      Resolv::DNS.open do |dns|
        dns.timeouts = TIMEOUT_SECONDS
        yield dns
      end
    rescue Resolv::ResolvError, SocketError, IOError
      nil
    end
  end
end
