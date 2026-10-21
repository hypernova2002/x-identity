# Returned once, when a client is created or its secret rotated. The secret can't be read again.
class AppClientWithSecretSerializer
  # @param created [AppClients::Management::Created]
  def initialize(created)
    @created = created
  end

  # @return [Hash]
  def serializable_hash
    AppClientSerializer.new(@created.app_client).serializable_hash.merge(client_secret: @created.client_secret)
  end
end
