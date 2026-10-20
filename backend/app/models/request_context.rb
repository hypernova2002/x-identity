RequestContext = Data.define(:ip, :user_agent) do
  def self.blank
    new(ip: nil, user_agent: nil)
  end
end
