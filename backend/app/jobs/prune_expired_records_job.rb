# Hourly sweep for rows that can no longer be used. Requests prune a user's own rows as they create
# new ones (see Prunable); this catches the rows of users who never come back.
class PruneExpiredRecordsJob < ApplicationJob
  queue_as :maintenance

  def perform
    Prunable.delete_in_batches(OneTimeToken.spent)
    Prunable.delete_in_batches(RefreshToken.ended)
    Prunable.delete_in_batches(ConsumedSamlAssertion.expired)
    BrowserSession.prune_all!
  end
end
