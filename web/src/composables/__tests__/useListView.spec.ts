import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'

import { useListView } from '../useListView'
import type { Page } from '@/services/http'
import type { ListParams } from '@/services/list'

type Fetch = (params: ListParams) => Promise<Page<string>>

const page = (total = 60): Page<string> => ({ items: ['a', 'b'], total, perPage: 25 })

async function setup(path: string, options: Partial<Parameters<typeof useListView>[1]> = {}) {
  const fetch = vi.fn<Fetch>().mockResolvedValue(page())
  const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/list', component: { template: '<div />' } }] })
  await router.push(path)
  let list!: ReturnType<typeof useListView<string>>
  const Host = defineComponent({
    setup() {
      list = useListView(fetch, { defaultSort: 'name', filterKeys: ['status_eq', 'role_eq'], ...options })
      return () => null
    },
  })
  mount(Host, { global: { plugins: [router] } })
  await flushPromises()
  return { list, fetch, router }
}

describe('useListView', () => {
  afterEach(() => localStorage.clear())

  it('loads the first page, sorted by default', async () => {
    const { list, fetch } = await setup('/list')

    expect(fetch).toHaveBeenLastCalledWith({ page: 1, perPage: 25, search: '', sort: 'name', filters: {}, exactCount: undefined })
    expect(list.rows.value).toEqual(['a', 'b'])
    expect(list.total.value).toBe(60)
    expect(list.filtered.value).toBe(false)
  })

  it("restores the list from the URL, ignoring values it doesn't offer", async () => {
    const { list } = await setup('/list?page=3&per_page=50&search=casey&sort=-created_at&status_eq=active&plan_eq=pro', { syncRoute: true })

    expect(list.state.value).toEqual({ page: 3, perPage: 50, search: 'casey', sort: '-created_at', filters: { status_eq: 'active' } })
    expect(list.filtered.value).toBe(true)
  })

  it('falls back to defaults for a page or page size that make no sense', async () => {
    const { list } = await setup('/list?page=-2&per_page=37', { syncRoute: true })

    expect(list.state.value).toMatchObject({ page: 1, perPage: 25 })
  })

  it('keeps the list in the URL, leaving out defaults and keeping other parameters', async () => {
    const { list, router, fetch } = await setup('/list?tab=members', { syncRoute: true })

    list.state.value = { ...list.state.value, page: 2, search: 'casey', filters: { role_eq: 'admin' } }
    await flushPromises()

    expect(router.currentRoute.value.query).toEqual({ tab: 'members', page: '2', search: 'casey', role_eq: 'admin' })
    expect(fetch).toHaveBeenLastCalledWith(expect.objectContaining({ page: 2, search: 'casey', filters: { role_eq: 'admin' } }))
  })

  it('follows back and forward', async () => {
    const { list, router, fetch } = await setup('/list', { syncRoute: true })
    list.state.value = { ...list.state.value, page: 2 }
    await flushPromises()
    const calls = fetch.mock.calls.length

    await router.push('/list?page=4')
    await flushPromises()

    expect(list.state.value.page).toBe(4)
    expect(fetch.mock.calls.length).toBe(calls + 1)
  })

  it('remembers the chosen rows per page for the table, without a shared link overwriting it', async () => {
    localStorage.setItem('x-identity.table.users', JSON.stringify({ perPage: 100 }))

    const remembered = await setup('/list', { storageKey: 'users', syncRoute: true })
    expect(remembered.list.state.value.perPage).toBe(100)

    const shared = await setup('/list?per_page=10', { storageKey: 'users', syncRoute: true })
    expect(shared.list.state.value.perPage).toBe(10)
    expect(JSON.parse(localStorage.getItem('x-identity.table.users')!)).toEqual({ perPage: 100 })

    shared.list.state.value = { ...shared.list.state.value, perPage: 50 }
    await flushPromises()
    expect(JSON.parse(localStorage.getItem('x-identity.table.users')!)).toEqual({ perPage: 50 })
  })

  it('counts exactly when asked, until the list changes', async () => {
    const { list, fetch } = await setup('/list')

    await list.countExactly()
    expect(fetch).toHaveBeenLastCalledWith(expect.objectContaining({ exactCount: true }))

    list.state.value = { ...list.state.value, search: 'casey' }
    await flushPromises()
    expect(fetch).toHaveBeenLastCalledWith(expect.objectContaining({ search: 'casey', exactCount: undefined }))
  })
})
