import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { defineComponent, h, type Component } from 'vue'
import { createMemoryHistory, createRouter } from 'vue-router'
import OpenVue from 'openvue/config'

import BaseDataTable from '../BaseDataTable.vue'
import type { DataTableColumn, DataTableFilter } from '../types'
import { useListView, type ListState } from '@/composables/useListView'
import type { Page } from '@/services/http'
import type { ListParams } from '@/services/list'

interface Row {
  uid: string
  name: string
}

const columns: DataTableColumn[] = [
  { key: 'name', label: 'Name', sortKey: 'name' },
  { key: 'uid', label: 'ID' },
]
const filters: DataTableFilter[] = [
  { type: 'text', key: 'actor_uid_eq', label: 'Actor ID' },
  { type: 'date', key: 'created_at_gteq', label: 'From' },
]
const initial: ListState = { page: 2, search: '', sort: 'name', filters: {} }

function mountTable(state: ListState = initial, props: Record<string, unknown> = {}) {
  return mount(BaseDataTable<Row>, {
    props: {
      state,
      caption: 'People',
      searchLabel: 'Search',
      columns,
      filters,
      rows: [{ uid: 'p_1', name: 'Casey' }],
      rowKey: (row: Row) => row.uid,
      total: 60,
      perPage: 25,
      emptyMessage: 'Nobody yet.',
      ...props,
    },
    global: { plugins: [[OpenVue, { unstyled: true }]] },
  })
}

function lastState(wrapper: ReturnType<typeof mountTable>) {
  const emitted = wrapper.emitted('update:state')!
  return emitted[emitted.length - 1]![0] as ListState
}

describe('BaseDataTable', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('debounces search and goes back to page 1', async () => {
    const wrapper = mountTable()

    await wrapper.get('input[type="search"]').setValue('cas')
    vi.advanceTimersByTime(299)
    expect(wrapper.emitted('update:state')).toBeUndefined()

    vi.advanceTimersByTime(1)
    expect(lastState(wrapper)).toEqual({ page: 1, search: 'cas', sort: 'name', filters: {} })
  })

  it('debounces text filters', async () => {
    const wrapper = mountTable()

    await wrapper.findAll('input[type="search"]')[1]!.setValue('usr_1')
    expect(wrapper.emitted('update:state')).toBeUndefined()

    vi.advanceTimersByTime(300)
    expect(lastState(wrapper).filters).toEqual({ actor_uid_eq: 'usr_1' })
  })

  it('applies date filters immediately', async () => {
    const wrapper = mountTable()

    await wrapper.get('input[type="date"]').setValue('2026-10-01')

    expect(lastState(wrapper)).toEqual({ page: 1, search: '', sort: 'name', filters: { created_at_gteq: '2026-10-01' } })
  })

  it('toggles a sortable column between ascending and descending, and marks it with aria-sort', async () => {
    const wrapper = mountTable()

    expect(wrapper.get('th').attributes('aria-sort')).toBe('ascending')
    await wrapper.get('th button').trigger('click')

    expect(lastState(wrapper)).toMatchObject({ sort: '-name', page: 1 })
  })

  it('pages with 1-based page numbers from the server total', async () => {
    const wrapper = mountTable()

    expect(wrapper.text()).toContain('Page 2 of 3')
    await wrapper.findAll('button').find((button) => button.text() === 'Next')!.trigger('click')

    expect(lastState(wrapper).page).toBe(3)
  })

  it('tells "nothing yet" apart from "nothing matches"', () => {
    expect(mountTable(initial, { rows: [] }).text()).toContain('Nobody yet.')
    expect(mountTable({ ...initial, search: 'zed' }, { rows: [] }).text()).toContain('Nothing matches')
  })

  it('shows a failed load with a way to retry', async () => {
    const wrapper = mountTable(initial, { rows: [], error: { message: 'Server unavailable' } })

    expect(wrapper.text()).toContain('Server unavailable')
    await wrapper.findAll('button').find((button) => button.text() === 'Try again')!.trigger('click')

    expect(wrapper.emitted('retry')).toHaveLength(1)
  })
})

describe('a data table with useListView', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('sends the search to the server instead of filtering the page it has', async () => {
    const fetch = vi.fn<(params: ListParams) => Promise<Page<Row>>>(async (params) =>
      params.search ? { items: [{ uid: 'p_99', name: 'Robin (page 4)' }], total: 1, perPage: 25 } : { items: [{ uid: 'p_1', name: 'Casey' }], total: 80, perPage: 25 },
    )
    const Harness = defineComponent(() => {
      const list = useListView(fetch, { defaultSort: 'name' })
      return () =>
        // Render functions can't infer a generic component's props.
        h(BaseDataTable as Component, {
          state: list.state.value,
          'onUpdate:state': (next: ListState) => (list.state.value = next),
          caption: 'People',
          searchLabel: 'Search',
          columns,
          rows: list.rows.value,
          rowKey: (row: Row) => row.uid,
          total: list.total.value,
          perPage: list.perPage.value,
          emptyMessage: 'Nobody yet.',
        })
    })
    const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/', component: { render: () => null } }] })
    const wrapper = mount(Harness, { global: { plugins: [router, [OpenVue, { unstyled: true }]] } })
    await flushPromises()

    await wrapper.get('input[type="search"]').setValue('robin')
    vi.advanceTimersByTime(300)
    await flushPromises()

    expect(fetch).toHaveBeenLastCalledWith(expect.objectContaining({ search: 'robin', page: 1, sort: 'name' }))
    expect(wrapper.text()).toContain('Robin (page 4)')
    expect(wrapper.text()).not.toContain('Casey')
  })
})
