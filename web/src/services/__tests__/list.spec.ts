import { describe, expect, it } from 'vitest'

import { listQuery } from '../list'

describe('listQuery', () => {
  it('serialises page, page size, sort, search and filters', () => {
    expect(listQuery({ page: 3, perPage: 50, sort: '-name', search: ' casey ', filters: { role_eq: 'admin', kind_in: ['google', 'apple'] } })).toEqual({
      page: 3,
      per_page: 50,
      sort: '-name',
      'q[search]': 'casey',
      'q[role_eq]': 'admin',
      'q[kind_in]': ['google', 'apple'],
    })
  })

  it('leaves out unset values, the first page and blank search', () => {
    expect(listQuery({ page: 1, search: '   ', sort: '', filters: { role_eq: '', status_eq: undefined, kind_in: [] } })).toEqual({})
  })

  it('makes a picked date cover the whole day, in UTC', () => {
    expect(listQuery({ filters: { created_at_gteq: '2026-10-01', created_at_lteq: '2026-10-31' } })).toEqual({
      'q[created_at_gteq]': '2026-10-01T00:00:00Z',
      'q[created_at_lteq]': '2026-10-31T23:59:59.999Z',
    })
  })
})
