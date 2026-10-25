module EndUsers
  # Headline counts for a project's end-user directory, in one query. Cached briefly, because a
  # project can have millions of end users.
  class Stats
    CACHE_FOR = 1.minute
    RECENT = 30.days

    # @param project [Project]
    def initialize(project)
      @project = project
    end

    # @return [Hash{Symbol => Integer}] total, active, disabled, invitation_pending and signed_in_recently (the last 30 days)
    def call
      Rails.cache.fetch([ "end_user_stats", @project.id ], expires_in: CACHE_FOR) { count }
    end

    private

    def count
      total, active, disabled, invitation_pending, signed_in_recently = @project.end_users.pick(
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(*) FILTER (WHERE status = 'active')"),
        Arel.sql("COUNT(*) FILTER (WHERE status = 'disabled')"),
        Arel.sql("COUNT(*) FILTER (WHERE password_digest IS NULL AND NOT EXISTS " \
                 "(SELECT 1 FROM end_user_identities WHERE end_user_identities.end_user_id = end_users.id))"),
        Arel.sql(ApplicationRecord.sanitize_sql_array([ "COUNT(*) FILTER (WHERE last_sign_in_at >= ?)", RECENT.ago ]))
      )
      { total: total, active: active, disabled: disabled, invitation_pending: invitation_pending, signed_in_recently: signed_in_recently }
    end
  end
end
