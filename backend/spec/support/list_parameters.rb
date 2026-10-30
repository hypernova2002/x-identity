# OpenAPI parameters of the list endpoints: search, filters, sort and pagination (see ListQuery).
module ListParameters
  module_function

  EXACT_COUNT = {
    name: :exact_count, in: :query, schema: { type: :string, enum: %w[true] },
    description: "Count every matching row for the Total header. Otherwise Total is exact up to #{Paginated::COUNT_CAP} rows, " \
      "and a lower bound past that, with Total-Capped: true."
  }.freeze

  # @param search [String] what `q[search]` matches
  # @param sorts [Array<String>] sort keys; each can be prefixed with `-` for descending
  # @param filters [Hash{Symbol => Hash}] the other `q` predicates and their schemas
  # @param capped [Boolean] whether the list caps its Total (see Paginated)
  # @return [Array<Hash>] arguments for `parameter`
  def build(search:, sorts:, filters: {}, capped: false)
    [
      {
        name: :q, in: :query, style: :deepObject, explode: true,
        schema: { type: :object, properties: { search: { type: :string, description: search }, **filters } }
      },
      { name: :sort, in: :query, schema: { type: :string, enum: sorts.flat_map { |key| [ key, "-#{key}" ] } }, description: "`-` sorts descending." },
      { name: :page, in: :query, schema: { type: :integer, minimum: 1, maximum: Paginated::MAX_PAGE } },
      { name: :per_page, in: :query, schema: { type: :integer, minimum: 1 }, description: "Values above #{Paginated::MAX_PER_PAGE} are capped." },
      *(capped ? [ EXACT_COUNT ] : [])
    ]
  end
end
