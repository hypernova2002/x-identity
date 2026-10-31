import { beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'

import { useAccountFromRoute } from '../useAccountFromRoute'
import { authService } from '@/services/auth'
import { ApiError } from '@/services/http'

vi.mock('@/services/auth', () => ({ authService: { lookupAccount: vi.fn<(typeof authService)['lookupAccount']>() } }))

const lookup = vi.mocked(authService.lookupAccount)

async function setup(path: string) {
  const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/:slug/sign-in', component: { template: '<div />' } }] })
  await router.push(path)
  let account!: ReturnType<typeof useAccountFromRoute>
  mount(defineComponent({ setup: () => ((account = useAccountFromRoute()), () => null) }), { global: { plugins: [router] } })
  await flushPromises()
  return { account, router }
}

describe('useAccountFromRoute', () => {
  beforeEach(() => {
    lookup.mockReset()
  })

  it("looks up the account in the URL, and again when it changes", async () => {
    lookup.mockImplementation(async (slug) => ({ uid: `acc_${slug}`, name: slug, slug }))
    const { account, router } = await setup('/acme/sign-in')
    expect(account.account.value).toMatchObject({ uid: 'acc_acme' })
    expect(account.loading.value).toBe(false)

    await router.push('/globex/sign-in')
    await flushPromises()

    expect(account.slug.value).toBe('globex')
    expect(account.account.value).toMatchObject({ uid: 'acc_globex' })
  })

  it("reports an account that doesn't exist, or a lookup that failed", async () => {
    lookup.mockRejectedValueOnce(new ApiError('not_found', 404))
    const missing = await setup('/nobody/sign-in')
    expect(missing.account.error.value).toMatchObject({ code: 'not_found' })
    expect(missing.account.account.value).toBeNull()

    lookup.mockRejectedValueOnce(new TypeError('boom'))
    const broken = await setup('/acme/sign-in')
    expect(broken.account.error.value).toMatchObject({ code: 'internal_error' })
  })
})
