# Pagy pagination with metadata in the Total, Per-Page and Link response headers.
#
# Lists that can grow very large count at most a little past the page being viewed: the Total
# header is exact up to {COUNT_CAP} rows, and past that it's a lower bound, flagged with
# `Total-Capped: true`, so a page never pays to count a huge table. `exact_count=true` asks for the
# real total anyway, for when someone needs it.
module Paginated
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  COUNT_CAP = 10_000

  private

  # @param scope [ActiveRecord::Relation, #count]
  # @param capped [Boolean] count at most {COUNT_CAP} rows (or up to the requested page, if further)
  def paginated(scope, capped: false)
    per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
    return paginate(scope, per_page: per_page) unless capped && params[:exact_count] != "true"

    page = [ params.fetch(:page, 1).to_i, 1 ].max
    limit = [ COUNT_CAP, page * per_page ].max
    count = scope.except(:order).limit(limit + 1).count(:all)
    page_of_rows = paginate(scope, per_page: per_page, count: count)
    if count > limit
      response.headers["Total"] = limit.to_s
      response.headers["Total-Capped"] = "true"
    end
    page_of_rows
  end
end
