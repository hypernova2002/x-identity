/**
 * The request shape shared by every list endpoint: `page` (1-based), `per_page`, `sort` (a key,
 * `-` prefixed for descending), `q[search]` and `q[<predicate>]` filters. Unset values are left out.
 */
export interface ListParams {
  page?: number
  perPage?: number
  search?: string
  sort?: string
  /** Keyed by the endpoint's filter predicate, e.g. `role_eq` or `kind_in`. */
  filters?: Record<string, string | readonly string[] | undefined>
}

/** For filling selects and lookups rather than a paged table: the largest page the API allows. */
export const LOOKUP: ListParams = { perPage: 100 }

/** How many options a searchable dropdown shows at once; it searches the server for the rest. */
export const LOOKUP_SIZE = 20

/** One page of options for a searchable dropdown, and how many match in total. */
export interface LookupPage {
  items: { label: string; value: string }[]
  total: number
}

/** Turns a list endpoint into a dropdown search: the first LOOKUP_SIZE matches, by its own search. */
export function lookupFrom<T>(
  fetch: (params: ListParams) => Promise<{ items: T[]; total: number }>,
  toOption: (item: T) => { label: string; value: string },
  filters: ListParams['filters'] = {},
) {
  return async (term: string): Promise<LookupPage> => {
    const page = await fetch({ search: term, perPage: LOOKUP_SIZE, filters })
    return { items: page.items.map(toOption), total: page.total }
  }
}

export type ListQuery = Record<string, string | number | readonly string[] | undefined>

const isSet = (value: string | readonly string[] | undefined) => (Array.isArray(value) ? value.length > 0 : value !== undefined && value !== '')

/** A date picked for a range filter covers the whole day, in UTC. */
function dateBound(key: string, value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return value
  if (key.endsWith('_gteq')) return `${value}T00:00:00Z`
  if (key.endsWith('_lteq')) return `${value}T23:59:59.999Z`
  return value
}

export function listQuery(params: ListParams): ListQuery {
  const query: ListQuery = {}
  if (params.page !== undefined && params.page > 1) query.page = params.page
  if (params.perPage !== undefined) query.per_page = params.perPage
  if (params.sort) query.sort = params.sort
  const search = params.search?.trim()
  if (search) query['q[search]'] = search
  for (const [key, value] of Object.entries(params.filters ?? {})) {
    if (isSet(value)) query[`q[${key}]`] = typeof value === 'string' ? dateBound(key, value) : value
  }
  return query
}
