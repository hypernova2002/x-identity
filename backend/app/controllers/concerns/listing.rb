# Search, filters, sort and pagination for list endpoints. See {ListQuery} for the request format.
module Listing
  include Paginated

  private

  # @param scope [ActiveRecord::Relation]
  # @param query [ListQuery]
  # @return [ActiveRecord::Relation] the requested page
  def listed(scope, query)
    paginated(query.call(scope, params))
  end
end
