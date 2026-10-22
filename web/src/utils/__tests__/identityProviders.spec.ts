import { describe, expect, it } from 'vitest'

import { emptyProviderDraft, providerDraftFrom, providerInputFrom, withProviderMetadata } from '../identityProviders'
import type { IdentityProvider } from '@/types/api'

describe('providerInputFrom', () => {
  it('sends Google settings with the secret when one is entered', () => {
    const draft = { ...emptyProviderDraft('google'), clientId: ' web.apps ', clientSecret: 'shh', additionalAudiences: 'ios, android' }

    expect(providerInputFrom(draft)).toEqual({
      name: 'Google',
      client_id: 'web.apps',
      client_secret: 'shh',
      additional_audiences: ['ios', 'android'],
      create_users: false,
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
      create_users: false,
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
      saml_idp_certificates: [],
      saml_name_id_format: 'email',
      domains: [],
      create_users: false,
      allow_idp_initiated: false,
      group_mappings: [],
    } as unknown as IdentityProvider

    expect(providerDraftFrom(provider)).toMatchObject({ clientSecret: '', additionalAudiences: 'cli', discoveryUrl: 'https://login.example.com' })
  })
})

describe('SAML providers', () => {
  const certificate = (body: string) => `-----BEGIN CERTIFICATE-----\n${body}\n-----END CERTIFICATE-----`

  it('sends the SAML settings, splitting pasted certificates and dropping half-filled group mappings', () => {
    const draft = {
      ...emptyProviderDraft('saml'),
      name: 'Acme SSO',
      samlEntityId: 'https://idp.acme.com',
      samlSsoUrl: 'https://idp.acme.com/sso',
      samlCertificates: `${certificate('AAA')}\n\n${certificate('BBB')}`,
      samlGroupsAttribute: 'groups',
      domains: 'acme.com, acme.co.uk',
      groupMappings: [
        { value: 'acme-eng', groupUid: 'grp_1' },
        { value: '', groupUid: 'grp_2' },
      ],
    }

    expect(providerInputFrom(draft)).toMatchObject({
      saml_idp_entity_id: 'https://idp.acme.com',
      saml_slo_url: null,
      saml_idp_certificates: [certificate('AAA'), certificate('BBB')],
      saml_email_attribute: null,
      domains: ['acme.com', 'acme.co.uk'],
      create_users: true,
      group_mappings: [{ value: 'acme-eng', group_uid: 'grp_1' }],
    })
    expect(providerInputFrom(draft)).not.toHaveProperty('client_id')
  })

  it('fills in what the metadata provides', () => {
    const draft = withProviderMetadata(emptyProviderDraft('saml'), { saml_idp_entity_id: 'https://idp.acme.com', saml_idp_certificates: ['A', 'B'] })

    expect(draft).toMatchObject({ samlEntityId: 'https://idp.acme.com', samlCertificates: 'A\nB', samlSsoUrl: '' })
  })
})
