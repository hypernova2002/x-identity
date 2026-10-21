import { describe, expect, it } from 'vitest'

import { emptyProviderDraft, providerDraftFrom, providerInputFrom } from '../identityProviders'
import type { IdentityProvider } from '@/types/api'

describe('providerInputFrom', () => {
  it('sends Google settings with the secret when one is entered', () => {
    const draft = { ...emptyProviderDraft('google'), clientId: ' web.apps ', clientSecret: 'shh', additionalAudiences: 'ios, android' }

    expect(providerInputFrom(draft)).toEqual({
      name: 'Google',
      client_id: 'web.apps',
      client_secret: 'shh',
      additional_audiences: ['ios', 'android'],
      scopes: 'openid email profile',
    })
  })

  it('leaves blank secrets out so the current ones are kept', () => {
    expect(providerInputFrom(emptyProviderDraft('oidc'))).not.toHaveProperty('client_secret')
    expect(providerInputFrom(emptyProviderDraft('apple'))).not.toHaveProperty('apple_private_key')
  })

  it('sends only the Apple fields for Apple', () => {
    const draft = { ...emptyProviderDraft('apple'), clientId: 'com.example.web', appleTeamId: 'TEAM123456', appleKeyId: 'KEY1234567' }

    expect(providerInputFrom(draft)).toEqual({
      name: 'Apple',
      client_id: 'com.example.web',
      additional_audiences: [],
      apple_team_id: 'TEAM123456',
      apple_key_id: 'KEY1234567',
    })
  })
})

describe('providerDraftFrom', () => {
  it('starts with blank secrets', () => {
    const provider = {
      kind: 'oidc',
      name: 'Okta',
      client_id: 'okta',
      client_secret_set: true,
      additional_audiences: ['cli'],
      scopes: 'openid email',
      discovery_url: 'https://login.example.com',
      apple_team_id: null,
      apple_key_id: null,
    } as IdentityProvider

    expect(providerDraftFrom(provider)).toMatchObject({ clientSecret: '', additionalAudiences: 'cli', discoveryUrl: 'https://login.example.com' })
  })
})
