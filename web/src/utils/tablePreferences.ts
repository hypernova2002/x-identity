const KEY_PREFIX = 'x-identity.table'

/** How one viewer likes a table: rows per page and hidden columns, remembered in this browser. */
export interface TablePreferences {
  perPage?: number
  hiddenColumns?: string[]
}

const storageKey = (table: string) => `${KEY_PREFIX}.${table}`

export function readTablePreferences(table: string): TablePreferences {
  try {
    const parsed: unknown = JSON.parse(localStorage.getItem(storageKey(table)) ?? '{}')
    if (typeof parsed !== 'object' || parsed === null) return {}
    const { perPage, hiddenColumns } = parsed as Record<string, unknown>
    return {
      ...(typeof perPage === 'number' ? { perPage } : {}),
      ...(Array.isArray(hiddenColumns) ? { hiddenColumns: hiddenColumns.filter((key): key is string => typeof key === 'string') } : {}),
    }
  } catch {
    return {}
  }
}

export function saveTablePreferences(table: string, changes: TablePreferences) {
  try {
    localStorage.setItem(storageKey(table), JSON.stringify({ ...readTablePreferences(table), ...changes }))
  } catch {
    // Storage can be unavailable (private mode, blocked site data); the table then uses its defaults.
  }
}
