class DeviceSessionSerializer
  include Alba::Resource

  attributes :uid, :device_name, :device_type, :amr, :created_at, :last_seen_at
  attribute(:ip) { |session| session.last_ip }
  attribute(:user_agent) { |session| session.last_user_agent }
  attribute(:location) do |session|
    { city: session.city, region: session.region, country_code: session.country_code } if session.country_code || session.city
  end
  attribute(:current) { |session| session.id == params[:current_id] }
end
