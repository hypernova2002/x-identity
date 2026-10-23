# Applies a list endpoint's search, filters and sort to a scope.
#
# Requests use `q[search]` for free text, `q[<predicate>]` for the filters a listing allows, and
# `sort=<key>` or `sort=-<key>` (descending). Rows are always ordered by `id` last, so pages never
# overlap or skip rows.
class ListQuery
  # @param sorts [Hash{String => Symbol, String}] sort keys mapped to a column, or a SQL expression
  #   for derived values (written by the developer, never from the request)
  # @param default_sort [String] e.g. `"name"` or `"-created_at"`
  # @param search [String, nil] the ransack predicate `q[search]` maps to, e.g. `"name_or_email_cont"`
  # @param filters [Array<Symbol>] ransack predicates and scopes allowed in `q`
  def initialize(sorts:, default_sort:, search: nil, filters: [])
    @sorts = sorts
    @default_sort = default_sort
    @search = search
    @filters = filters
  end

  # @param scope [ActiveRecord::Relation]
  # @param params [ActionController::Parameters] the request's parameters
  # @return [ActiveRecord::Relation]
  # @raise [ApiError] `validation_failed` when the sort key isn't one of the listing's
  def call(scope, params)
    ordered(scope.ransack(conditions(params)).result, params[:sort].presence || @default_sort)
  end

  private

  def conditions(params)
    query = params.fetch(:q, {}).permit(:search, *@filters.map { |filter| filter.end_with?("_in") ? { filter => [] } : filter }).to_h
    search = query.delete("search")
    query[@search] = search if @search && search.present?
    query
  end

  def ordered(scope, sort)
    direction = sort.start_with?("-") ? :desc : :asc
    key = sort.delete_prefix("-")
    column = @sorts.fetch(key) { raise ApiError.validation(sort: "Sort by one of: #{@sorts.keys.join(', ')}.") }

    expression = column.is_a?(Symbol) ? scope.arel_table[column] : Arel.sql(column)
    scope.reorder(expression.public_send(direction).nulls_last, scope.arel_table[:id].public_send(direction))
  end
end
