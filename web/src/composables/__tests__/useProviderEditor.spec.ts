import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useProviderEditor } from '../useProviderEditor'
import { projectAdminService } from '@/services/project'
import type { IdentityProvider } from '@/types/api'

type Service = typeof projectAdminService

vi.mock('@/services/project', () => ({
  projectAdminService: {
    createIdentityProvider: vi.fn<Service['createIdentityProvider']>(),
    updateIdentityProvider: vi.fn<Service['updateIdentityProvider']>(),
    parseSamlProviderMetadata: vi.fn<Service['parseSamlProviderMetadata']>(),
  },
}))

const service = vi.mocked(projectAdminService)
const ids = { accountUid: 'acc_1', projectUid: 'prj_1' }

describe('useProviderEditor', () => {
  beforeEach(() => {
    vi.resetAllMocks()
  })

  it('creates a new provider of the chosen kind, then closes', async () => {
    const saved = { uid: 'idp_1' } as IdentityProvider
    service.createIdentityProvider.mockResolvedValue(saved)
    const editor = useProviderEditor(() => ids)

    editor.start(null, 'oidc')
    expect(editor.open.value).toBe(true)
    expect(editor.draft.value.kind).toBe('oidc')
    editor.draft.value.name = 'Okta'
    editor.draft.value.clientId = ' client-1 '

    await expect(editor.save.run()).resolves.toBe(saved)
    expect(service.createIdentityProvider).toHaveBeenCalledWith('acc_1', 'prj_1', 'oidc', expect.objectContaining({ name: 'Okta', client_id: 'client-1' }))
    expect(editor.open.value).toBe(false)
  })

  it('updates the provider being edited, and stays open when saving fails', async () => {
    service.updateIdentityProvider.mockRejectedValue(new Error('offline'))
    const editor = useProviderEditor(() => ids)
    const provider: IdentityProvider = {
      uid: 'idp_1',
      kind: 'google',
      name: 'Google',
      enabled: true,
      client_id: 'g-1',
      client_secret_set: true,
      additional_audiences: [],
      scopes: 'openid email',
      discovery_url: null,
      issuer: null,
      apple_team_id: null,
      apple_key_id: null,
      apple_private_key_set: false,
      callback_url: 'https://api.test/callback',
      saml_idp_entity_id: null,
      saml_sso_url: null,
      saml_slo_url: null,
      saml_idp_certificates: [],
      saml_name_id_format: 'email',
      saml_email_attribute: null,
      saml_name_attribute: null,
      saml_groups_attribute: null,
      domains: [],
      create_users: true,
      allow_idp_initiated: false,
      on_custom_domain: null,
      sp_entity_id: null,
      acs_url: null,
      sp_slo_url: null,
      group_mappings: [],
      created_at: '2026-10-01T09:00:00Z',
      updated_at: '2026-10-01T09:00:00Z',
    }

    editor.start(provider)
    await editor.save.run()

    expect(service.updateIdentityProvider).toHaveBeenCalledWith('acc_1', 'prj_1', 'idp_1', expect.objectContaining({ name: 'Google', client_id: 'g-1' }))
    expect(service.createIdentityProvider).not.toHaveBeenCalled()
    expect(editor.open.value).toBe(true)
    expect(editor.save.error.value).toBeTruthy()
  })

  it("fills a SAML provider's details from its metadata", async () => {
    service.parseSamlProviderMetadata.mockResolvedValue({ saml_idp_entity_id: 'https://idp.test', saml_sso_url: 'https://idp.test/sso' })
    const editor = useProviderEditor(() => ids)
    editor.start(null, 'saml')

    await editor.importMetadata.run({ metadata_url: 'https://idp.test/metadata' })

    expect(service.parseSamlProviderMetadata).toHaveBeenCalledWith('acc_1', 'prj_1', { metadata_url: 'https://idp.test/metadata' })
    expect(editor.draft.value).toMatchObject({ samlEntityId: 'https://idp.test', samlSsoUrl: 'https://idp.test/sso' })
  })
})
