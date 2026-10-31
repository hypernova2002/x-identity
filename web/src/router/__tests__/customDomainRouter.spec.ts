import { describe, expect, it, vi } from 'vitest'

// On a project's custom domain the router only has the hosted pages, at the root.
vi.hoisted(() => vi.stubEnv('VITE_CONSOLE_URL', 'https://console.example.test'))

const { default: router } = await import('@/router')

describe('router on a custom domain', () => {
  it('serves the hosted pages at the root', async () => {
    await router.push('/login?interaction=int_1')

    expect(router.currentRoute.value.name).toBe('hosted-login')
  })

  it("doesn't serve the console", async () => {
    await router.push('/console')

    expect(router.currentRoute.value.name).toBe('not-found')
  })
})
