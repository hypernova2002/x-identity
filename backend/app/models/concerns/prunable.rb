# Deleting rows that can no longer be used, a batch at a time, from inside the requests that create
# new ones. Each call is bounded, so a backlog never slows a single request much; active users and
# apps clean up after themselves as they go. {PruneExpiredRecordsJob} sweeps up after the rest.
module Prunable
  BATCH = 100
  SWEEP_BATCH = 1_000

  # @param scope [ActiveRecord::Relation] rows to delete
  # @return [Integer] how many were deleted
  def self.delete_batch(scope)
    scope.limit(BATCH).delete_all
  end

  # Deletes every row in the scope, walking the table by id so each batch starts where the last stopped.
  # @param scope [ActiveRecord::Relation] rows to delete
  # @return [Integer] how many were deleted
  def self.delete_in_batches(scope)
    scope.in_batches(of: SWEEP_BATCH).delete_all
  end
end
