module Apps
  # How many applications a project has, by kind, matching the kinds {Directory} filters on.
  class Stats
    # @param project [Project]
    def initialize(project)
      @project = project
    end

    # @return [Hash{Symbol => Integer}] total, oidc, machine and saml
    def call
      oidc, machine = @project.app_clients.managed.pick(Arel.sql("COUNT(*) FILTER (WHERE NOT machine)"), Arel.sql("COUNT(*) FILTER (WHERE machine)"))
      saml = @project.saml_apps.count
      { total: oidc + machine + saml, oidc: oidc, machine: machine, saml: saml }
    end
  end
end
