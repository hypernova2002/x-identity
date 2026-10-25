import { afterEach, describe, expect, it, vi } from 'vitest'

import { apiBaseUrl, onCustomDomain, projectPath } from '../customDomain'
import { hostedLoginService } from '@/services/hostedLogin'

describe('custom domains', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
  })

  it('treats the console origin as x-identity, with project endpoints under the API', () => {
    vi.stubEnv('VITE_CONSOLE_URL', window.location.origin)
    vi.stubEnv('VITE_API_BASE_URL', 'http://api.example.test')

    expect(onCustomDomain()).toBe(false)
    expect(apiBaseUrl()).toBe('http://api.example.test')
    expect(projectPath('acct_1', 'proj_1')).toBe('/v1/accounts/acct_1/projects/proj_1')
    expect(hostedLoginService.providerUrl({ accountUid: 'acct_1', projectUid: 'proj_1', interaction: 'int' }, 'idp_1')).toBe(
      'http://api.example.test/v1/accounts/acct_1/projects/proj_1/oauth2/interactions/int/providers/idp_1',
    )
  })

  it('on any other origin, calls the project endpoints at the root of the same origin', () => {
    vi.stubEnv('VITE_CONSOLE_URL', 'http://console.example.test')
    vi.stubEnv('VITE_API_BASE_URL', 'http://api.example.test')

    expect(onCustomDomain()).toBe(true)
    expect(apiBaseUrl()).toBe('')
    expect(projectPath('acct_1', 'proj_1')).toBe('')
    expect(hostedLoginService.providerUrl({ accountUid: 'acct_1', projectUid: 'proj_1', interaction: 'int' }, 'idp_1')).toBe(
      '/oauth2/interactions/int/providers/idp_1',
    )
  })

  it('stays on x-identity when the console URL isn\'t configured', () => {
    vi.stubEnv('VITE_CONSOLE_URL', '')

    expect(onCustomDomain()).toBe(false)
  })
})
