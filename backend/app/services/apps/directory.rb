module Apps
  # A project's app clients and SAML apps as one list, searched, filtered, sorted and paged in the
  # database. It answers `count`, `offset` and `limit` like a relation, so it paginates like one.
  #
  # Requests use `q[search]` (name or uid), `q[app_type_eq]` (`app_client` or `saml_app`),
  # `q[kind_eq]` (`oidc`, `machine` or `saml`), `q[enabled_eq]`, `q[machine_eq]` and `sort` (`name`, `type` or `created_at`, `-` for descending).
  class Directory
    include Enumerable

    Row = Data.define(:app_type, :uid, :name, :enabled, :client_type, :machine, :entity_id, :created_at, :assignment_count, :api_count)

    SORTS = { "name" => :name, "type" => :app_type, "created_at" => :created_at }.freeze
    TABLE = Arel::Table.new(:applications)
    KINDS = {
      "oidc" => TABLE[:app_type].eq("app_client").and(TABLE[:machine].eq(false)),
      "machine" => TABLE[:machine].eq(true),
      "saml" => TABLE[:app_type].eq("saml_app")
    }.freeze

    # @param project [Project]
    # @param params [ActionController::Parameters]
    # @raise [ApiError] `validation_failed` when the sort key isn't one of {SORTS}
    def initialize(project, params, offset: 0, limit: nil)
      @project = project
      @params = params
      @query = params.fetch(:q, {}).permit(:search, :app_type_eq, :kind_eq, :enabled_eq, :machine_eq)
      @sort = params[:sort].presence || "name"
      @offset = offset
      @limit = limit
      sort_column
    end

    # @return [Directory]
    def offset(value)
      self.class.new(@project, @params, offset: value, limit: @limit)
    end

    # @return [Directory]
    def limit(value)
      self.class.new(@project, @params, offset: @offset, limit: value)
    end

    # @return [Integer] how many applications match, across all pages
    def count(*)
      connection.select_value(filtered.project(Arel.star.count)).to_i
    end

    def each(&)
      rows.each(&)
    end

    private

    def rows
      manager = filtered.project(Arel.star).order(TABLE[sort_column].public_send(direction), TABLE[:app_type].asc, TABLE[:id].public_send(direction))
      manager.skip(@offset).take(@limit)
      result = connection.select_all(manager)
      result.cast_values.map { |values| Row.new(**result.columns.zip(Array(values)).to_h.symbolize_keys.slice(*Row.members)) }
    end

    def filtered
      manager = Arel::SelectManager.new(source)
      if @query[:search].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(@query[:search])}%"
        manager.where(TABLE[:name].matches(term).or(TABLE[:uid].matches(term)))
      end
      manager.where(TABLE[:app_type].eq(@query[:app_type_eq])) if @query[:app_type_eq].present?
      manager.where(TABLE[:enabled].eq(ActiveModel::Type::Boolean.new.cast(@query[:enabled_eq]))) if @query[:enabled_eq].present?
      manager.where(TABLE[:machine].eq(ActiveModel::Type::Boolean.new.cast(@query[:machine_eq]))) if @query[:machine_eq].present?
      manager.where(KINDS[@query[:kind_eq]]) if KINDS.key?(@query[:kind_eq])
      manager
    end

    def source
      clients = @project.app_clients.managed.select(
        Arel.sql("'app_client'").as("app_type"), :id, :uid, :name, :enabled, :client_type, :machine, Arel.sql("NULL").as("entity_id"), :created_at,
        assignment_count("AppClient", "app_clients"), Arel.sql("(SELECT COUNT(*) FROM api_grants WHERE api_grants.app_client_id = app_clients.id)").as("api_count")
      )
      saml_apps = @project.saml_apps.select(
        Arel.sql("'saml_app'").as("app_type"), :id, :uid, :name, :enabled, Arel.sql("NULL").as("client_type"), Arel.sql("FALSE").as("machine"), :entity_id,
        :created_at, assignment_count("SamlApp", "saml_apps"), Arel.sql("0").as("api_count")
      )
      Arel::Nodes::TableAlias.new(Arel.sql("(#{clients.to_sql} UNION ALL #{saml_apps.to_sql})"), "applications")
    end

    # Users and groups assigned to each app, counted in the same query.
    def assignment_count(app_type, table)
      Arel.sql("(SELECT COUNT(*) FROM app_assignments WHERE app_assignments.app_type = '#{app_type}' AND app_assignments.app_id = #{table}.id)")
        .as("assignment_count")
    end

    def sort_column
      SORTS.fetch(@sort.delete_prefix("-")) { raise ApiError.validation(:sort, :unknown_sort, values: SORTS.keys) }
    end

    def direction
      @sort.start_with?("-") ? :desc : :asc
    end

    def connection
      ApplicationRecord.connection
    end
  end
end
