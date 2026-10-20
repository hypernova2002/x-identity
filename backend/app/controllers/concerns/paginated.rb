# Pagy pagination with metadata in the Total, Per-Page and Link response headers.
module Paginated
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  private

  def paginated(scope)
    paginate(scope, per_page: params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE))
  end
end
