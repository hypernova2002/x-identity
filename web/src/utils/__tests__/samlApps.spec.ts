import { describe, expect, it } from 'vitest'

import { emptySamlAppDraft, samlAppDraftFrom, samlAppInputFrom, withMetadata } from '../samlApps'
import type { SamlApp } from '@/types/api'

describe('samlAppInputFrom', () => {
  it('turns the form into the API body', () => {
    const draft = {
      ...emptySamlAppDraft(),
      name: ' Wiki ',
      entityId: 'https://wiki.test/saml',
      acsUrls: 'https://wiki.test/acs, https://wiki.test/acs2',
      attributeMappings: [
        { name: 'mail', source: 'email' as const, customKey: '' },
        { name: 'role', source: 'custom' as const, customKey: 'role' },
        { name: ' ', source: 'uid' as const, customKey: '' },
      ],
    }

    expect(samlAppInputFrom(draft)).toMatchObject({
      name: 'Wiki',
      acs_urls: ['https://wiki.test/acs', 'https://wiki.test/acs2'],
      slo_url: null,
      sp_certificate: null,
      attribute_mappings: [
        { name: 'mail', source: 'email' },
        { name: 'role', source: 'custom:role' },
      ],
    })
  })
})

describe('samlAppDraftFrom', () => {
  it('splits custom attribute sources back out', () => {
    const app = { ...samlAppInputFrom(emptySamlAppDraft()), attribute_mappings: [{ name: 'role', source: 'custom:role' }] } as unknown as SamlApp

    expect(samlAppDraftFrom(app).attributeMappings).toEqual([{ name: 'role', source: 'custom', customKey: 'role' }])
  })
})

describe('withMetadata', () => {
  it('fills in what the metadata provides and keeps the rest', () => {
    const draft = { ...emptySamlAppDraft(), name: 'Wiki', sloUrl: 'https://kept.test' }

    expect(withMetadata(draft, { entity_id: 'https://wiki.test/saml', acs_urls: ['https://wiki.test/acs'] })).toMatchObject({
      name: 'Wiki',
      entityId: 'https://wiki.test/saml',
      acsUrls: 'https://wiki.test/acs',
      sloUrl: 'https://kept.test',
    })
  })
})
