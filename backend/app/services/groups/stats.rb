module Groups
  # How many groups a project has, and how many of them have no members.
  class Stats
    # @param project [Project]
    def initialize(project)
      @project = project
    end

    # @return [Hash{Symbol => Integer}] total and empty
    def call
      total, empty = @project.groups.pick(
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM group_memberships WHERE group_memberships.group_id = groups.id))")
      )
      { total: total, empty: empty }
    end
  end
end
