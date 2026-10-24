export interface SelectOption<V extends string = string> {
  label: string
  value: V
}

export interface DataTableColumn {
  key: string
  label: string
  srOnly?: boolean
  /** The server's sort key; columns without one aren't sortable. */
  sortKey?: string
  /** How the sort directions are described where there are no headers: dates read newest/oldest first. */
  sortKind?: 'text' | 'date'
}

/** A filter on a data table. `key` is the endpoint's `q` predicate, e.g. `role_eq`. */
export type DataTableFilter =
  | { type: 'select'; key: string; label: string; options: readonly SelectOption[]; anyLabel?: string }
  | { type: 'text'; key: string; label: string }
  | { type: 'date'; key: string; label: string }
