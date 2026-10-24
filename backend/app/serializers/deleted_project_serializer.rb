class DeletedProjectSerializer
  include Alba::Resource

  attributes :uid, :name, :deleted_at, :purge_at
end
