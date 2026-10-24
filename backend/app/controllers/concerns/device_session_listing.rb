# A user's signed-in devices, most recently active first, paginated like other lists.
module DeviceSessionListing
  include Listing

  LIST = ListQuery.new(
    search: "device_name_or_last_ip_or_city_or_country_code_i_cont",
    sorts: { "last_seen_at" => :last_seen_at, "created_at" => :created_at },
    default_sort: "-last_seen_at"
  )

  private

  # @param user [User, EndUser]
  # @param current [DeviceSession, nil] marked as the device making the request
  def render_device_sessions(user, current: nil)
    sessions = listed(user.device_sessions.current, LIST)
    render json: DeviceSessionSerializer.new(sessions, params: { current_id: current&.id }).serializable_hash
  end
end
