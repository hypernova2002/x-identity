# Deleting rows that can no longer be used, a batch at a time, from inside the requests that create
# new ones. Each call is bounded, so a backlog never slows a single request much; active users and
# apps clean up after themselves as they go.
module Prunable
  BATCH = 100

  # @param scope [ActiveRecord::Relation] rows to delete
  # @return [Integer] how many were deleted
  def self.delete_batch(scope)
    scope.limit(BATCH).delete_all
  end
end
