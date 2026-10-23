# OpenAPI parameters of the list endpoints: search, filters, sort and pagination (see ListQuery).
module ListParameters
  module_function

  # @param search [String] what `q[search]` matches
  # @param sorts [Array<String>] sort keys; each can be prefixed with `-` for descending
  # @param filters [Hash{Symbol => Hash}] the other `q` predicates and their schemas
  # @return [Array<Hash>] arguments for `parameter`
  def build(search:, sorts:, filters: {})
    [
      {
        name: :q, in: :query, style: :deepObject, explode: true,
        schema: { type: :object, properties: { search: { type: :string, description: search }, **filters } }
      },
      { name: :sort, in: :query, schema: { type: :string, enum: sorts.flat_map { |key| [ key, "-#{key}" ] } }, description: "`-` sorts descending." },
      { name: :page, in: :query, schema: { type: :integer, minimum: 1 } },
      { name: :per_page, in: :query, schema: { type: :integer, minimum: 1 }, description: "Values above #{Paginated::MAX_PER_PAGE} are capped." }
    ]
  end
end
