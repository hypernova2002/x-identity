# Approximate location of an IP address, from a local DB-IP Lite city database (GeoIP2 format,
# CC BY 4.0, https://db-ip.com). Lookups never leave the server. Without the database file, or for
# private and loopback addresses, there is no location.
#
# The file is downloaded by `bin/rails geoip:download` (the production image does this at build).
class GeoIp
  Location = Data.define(:city, :region, :country_code)

  # @return [GeoIp] reading the configured database, loaded once per process
  def self.default
    @default ||= new(reader_for(Rails.application.config.x.geoip_database_path))
  end

  # @param path [String, Pathname]
  # @return [MaxMind::DB, nil]
  def self.reader_for(path)
    MaxMind::DB.new(path.to_s, mode: MaxMind::DB::MODE_FILE) if File.exist?(path.to_s)
  rescue MaxMind::DB::InvalidDatabaseError => error
    Rails.logger.warn("GeoIP database at #{path} couldn't be read: #{error.message}")
    nil
  end

  # @param reader [#get, nil] answers `get(ip)` with a GeoIP2 city record
  def initialize(reader)
    @reader = reader
  end

  # @param ip [String, nil]
  # @return [Location, nil]
  def lookup(ip)
    return nil if @reader.nil? || !public_address?(ip)

    record = @reader.get(ip)
    return nil if record.nil?

    location = Location.new(
      city: english_name(record["city"]),
      region: english_name(Array(record["subdivisions"]).first),
      country_code: record.dig("country", "iso_code")
    )
    location if location.to_h.values.any?
  end

  private

  def public_address?(ip)
    address = IPAddr.new(ip.to_s)
    !(address.private? || address.loopback? || address.link_local?)
  rescue IPAddr::InvalidAddressError
    false
  end

  def english_name(entry)
    entry&.dig("names", "en")
  end
end
