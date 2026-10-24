require "net/http"
require "zlib"

namespace :geoip do
  desc "Download the DB-IP Lite city database (CC BY 4.0) used for approximate device locations"
  task download: :environment do
    path = Pathname(Rails.application.config.x.geoip_database_path)
    path.dirname.mkpath

    # DB-IP publishes each month's file early in the month; fall back to last month's until then.
    months = [ Date.current, Date.current.prev_month ].map { |date| date.strftime("%Y-%m") }
    body = months.lazy.filter_map do |month|
      uri = URI("https://download.db-ip.com/free/dbip-city-lite-#{month}.mmdb.gz")
      response = Net::HTTP.get_response(uri)
      response.body if response.is_a?(Net::HTTPSuccess)
    end.first
    abort "Couldn't download the DB-IP Lite database for #{months.join(' or ')}." unless body

    temporary = path.sub_ext(".mmdb.tmp")
    temporary.binwrite(Zlib.gunzip(body))
    MaxMind::DB.new(temporary.to_s).close
    temporary.rename(path)
    puts "Saved #{path} (#{path.size / 1_000_000} MB). IP geolocation by DB-IP (https://db-ip.com), CC BY 4.0."
  end
end
