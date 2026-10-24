# Search, filters, sort and pagination for list endpoints. See {ListQuery} for the request format.
module Listing
  include Paginated

  private

  # @param scope [ActiveRecord::Relation]
  # @param query [ListQuery]
  # @param capped [Boolean] for lists that can grow very large; see {Paginated}
  # @return [ActiveRecord::Relation] the requested page
  def listed(scope, query, capped: false)
    paginated(query.call(scope, params), capped: capped)
  end
end
