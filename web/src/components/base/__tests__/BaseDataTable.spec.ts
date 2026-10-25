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
const initial: ListState = { page: 2, perPage: 25, search: '', sort: 'name', filters: {} }

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
    // OpenVue's Select, used for rows per page, asks for matchMedia, which jsdom lacks.
    vi.stubGlobal('matchMedia', (query: string) => ({ matches: false, media: query, addEventListener() {}, removeEventListener() {} }))
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('debounces search and goes back to page 1', async () => {
    const wrapper = mountTable()

    await wrapper.get('input[type="search"]').setValue('cas')
    vi.advanceTimersByTime(299)
    expect(wrapper.emitted('update:state')).toBeUndefined()

    vi.advanceTimersByTime(1)
    expect(lastState(wrapper)).toEqual({ page: 1, perPage: 25, search: 'cas', sort: 'name', filters: {} })
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

    expect(lastState(wrapper)).toEqual({ page: 1, perPage: 25, search: '', sort: 'name', filters: { created_at_gteq: '2026-10-01' } })
  })

  it('toggles a sortable column between ascending and descending, and marks it with aria-sort', async () => {
    const wrapper = mountTable()

    expect(wrapper.get('th').attributes('aria-sort')).toBe('ascending')
    await wrapper.get('th button').trigger('click')

    expect(lastState(wrapper)).toMatchObject({ sort: '-name', page: 1 })
  })

  it('pages with 1-based page numbers from the server total, from the toolbar and below the table', async () => {
    const wrapper = mountTable()

    expect(wrapper.get('nav[aria-label="Pagination"]').text()).toContain('26–26 of 60')
    expect(wrapper.get('nav[aria-label="Pagination, bottom"]').text()).toBe(wrapper.get('nav[aria-label="Pagination"]').text())
    await wrapper.get('nav[aria-label="Pagination, bottom"] button[aria-label="Next page"]').trigger('click')

    expect(lastState(wrapper).page).toBe(3)
  })

  it('always shows the paging controls, even with a single page', () => {
    const wrapper = mountTable({ ...initial, page: 1 }, { total: 1 })

    expect(wrapper.get('nav[aria-label="Pagination"]').text()).toContain('1–1 of 1')
    expect(wrapper.findAll('button[aria-label="Next page"]').every((button) => button.attributes('disabled') !== undefined)).toBe(true)
    expect(wrapper.findAll('button[aria-label="Previous page"]').every((button) => button.attributes('disabled') !== undefined)).toBe(true)
  })

  it('shows a capped page count as a lower bound', () => {
    const wrapper = mountTable({ ...initial, page: 3 }, { total: 10000, capped: true })

    expect(wrapper.get('nav[aria-label="Pagination"]').text()).toContain('51–51 of 10,000+')
    expect(wrapper.text()).toContain('Count exactly')
  })

  it('shows each search and filter as a removable chip, with Clear all', async () => {
    const wrapper = mountTable({ ...initial, search: 'cas', filters: { created_at_gteq: '2026-10-01', actor_uid_eq: 'usr_1' } })
    const chips = wrapper.get('ul[aria-label="Active filters"]')

    expect(chips.text()).toContain('Search: cas')
    expect(chips.text()).toContain('Actor ID: usr_1')
    expect(chips.text()).toContain('From: ')
    await chips.get('button[aria-label="Remove Actor ID: usr_1"]').trigger('click')
    expect(lastState(wrapper)).toEqual({ page: 1, perPage: 25, search: 'cas', sort: 'name', filters: { created_at_gteq: '2026-10-01' } })

    await chips.findAll('button').find((button) => button.text() === 'Clear all')!.trigger('click')
    expect(lastState(wrapper)).toMatchObject({ search: '', filters: {} })
  })

  it('shows the first two of many filters and puts the rest under More filters, counting those set', () => {
    const many: DataTableFilter[] = [
      ...filters,
      { type: 'select', key: 'role_eq', label: 'Role', options: [{ label: 'Admin', value: 'admin' }] },
      { type: 'select', key: 'status_eq', label: 'Status', options: [{ label: 'Active', value: 'active' }] },
    ]
    const wrapper = mountTable({ ...initial, filters: { status_eq: 'active' } }, { filters: many })
    const form = wrapper.get('form[role="search"]')

    expect(form.text()).toContain('Actor ID')
    expect(form.text()).toContain('From')
    expect(form.text()).not.toContain('Role')
    expect(form.text()).toContain('More filters (1)')
  })

  it('refreshes on request', async () => {
    const wrapper = mountTable()

    await wrapper.get('button[aria-label="Refresh"]').trigger('click')

    expect(wrapper.emitted('reload')).toHaveLength(1)
  })

  it('hides a chosen column and remembers it in this browser, but never the first column', async () => {
    localStorage.clear()
    const wrapper = mountTable(initial, { storageKey: 'people' })
    await wrapper.get('button[aria-label="Choose columns"]').trigger('click')
    await flushPromises()

    const checkboxes = document.body.querySelectorAll<HTMLInputElement>('input[type="checkbox"]')
    expect(checkboxes[0]!.disabled).toBe(true)
    checkboxes[1]!.click()
    await flushPromises()

    expect(wrapper.findAll('th').map((th) => th.text())).toEqual([expect.stringContaining('Name')])
    expect(JSON.parse(localStorage.getItem('x-identity.table.people')!)).toEqual({ hiddenColumns: ['uid'] })
    expect(mountTable(initial, { storageKey: 'people' }).findAll('th')).toHaveLength(1)
    wrapper.unmount()
  })

  it('tells "nothing yet" apart from "nothing matches"', () => {
    expect(mountTable(initial, { rows: [] }).text()).toContain('Nobody yet.')
    expect(mountTable({ ...initial, search: 'zed' }, { rows: [] }).text()).toContain('Nothing matches')
  })

  it('shows a failed load with a way to retry', async () => {
    const wrapper = mountTable(initial, { rows: [], error: { message: 'Server unavailable' } })

    expect(wrapper.text()).toContain('Server unavailable')
    await wrapper.findAll('button').find((button) => button.text() === 'Try again')!.trigger('click')

    expect(wrapper.emitted('reload')).toHaveLength(1)
  })
})

describe('a data table with useListView', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    // OpenVue's Select, used for rows per page, asks for matchMedia, which jsdom lacks.
    vi.stubGlobal('matchMedia', (query: string) => ({ matches: false, media: query, addEventListener() {}, removeEventListener() {} }))
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
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

  it('asks the server for the chosen rows per page, back on page 1, and remembers the choice', async () => {
    localStorage.clear()
    const fetch = vi.fn<(params: ListParams) => Promise<Page<Row>>>(async (params) => ({ items: [], total: 80, perPage: params.perPage ?? 25 }))
    const Harness = defineComponent(() => {
      const list = useListView(fetch, { defaultSort: 'name', storageKey: 'people' })
      list.state.value = { ...list.state.value, page: 3 }
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

    wrapper.findComponent({ name: 'BaseSelect' }).vm.$emit('update:modelValue', '50')
    await flushPromises()

    expect(fetch).toHaveBeenLastCalledWith(expect.objectContaining({ perPage: 50, page: 1 }))
    expect(JSON.parse(localStorage.getItem('x-identity.table.people')!)).toEqual({ perPage: 50 })
  })
})
