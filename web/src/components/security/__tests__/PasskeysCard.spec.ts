import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import PasskeysCard from '../PasskeysCard.vue'
import { ApiError } from '@/services/http'
import type { Passkey, PasskeyRegistrationOptions } from '@/types/api'
import { createPasskey, type PasskeyRegistrationJSON } from '@/utils/webauthn'

type List = () => Promise<Passkey[]>
type Options = () => Promise<PasskeyRegistrationOptions>
type Add = (registrationId: string, credential: PasskeyRegistrationJSON) => Promise<Passkey>

vi.mock('@/utils/webauthn', async (original) => ({
  ...(await original<typeof import('@/utils/webauthn')>()),
  passkeysSupported: () => true,
  createPasskey: vi.fn<typeof import('@/utils/webauthn').createPasskey>(),
}))

const passkey = (changes: Partial<Passkey> = {}): Passkey => ({
  uid: 'pk_1',
  name: 'Chrome on Mac',
  created_at: '2026-10-20T12:00:00Z',
  last_used_at: null,
  domain: window.location.hostname,
  synced: true,
  ...changes,
})

function mountCard(props: Partial<InstanceType<typeof PasskeysCard>['$props']> = {}) {
  return mount(PasskeysCard, {
    props: {
      available: true,
      list: vi.fn<List>(async () => [passkey()]),
      options: vi.fn<Options>(async () => ({ registration_id: 'reg_1', public_key: { challenge: 'AQID' } as never })),
      add: vi.fn<Add>(async () => passkey({ uid: 'pk_2', name: 'iPhone' })),
      rename: vi.fn<(passkeyUid: string, name: string) => Promise<Passkey>>(async () => passkey()),
      remove: vi.fn<(passkeyUid: string) => Promise<unknown>>(async () => null),
      ...props,
    },
    global: { plugins: [[OpenVue, { unstyled: true }]] },
  })
}

const button = (wrapper: ReturnType<typeof mountCard>, name: string) => wrapper.findAll('button').find((candidate) => candidate.text() === name)

describe('PasskeysCard', () => {
  beforeEach(() => {
    vi.mocked(createPasskey).mockReset()
  })

  it("lists passkeys, marking ones that belong to another domain", async () => {
    const wrapper = mountCard({ list: vi.fn<List>(async () => [passkey(), passkey({ uid: 'pk_old', name: 'Old', domain: 'old.acme.com', synced: false })]) })
    await flushPromises()

    expect(wrapper.text()).toContain('Chrome on Mac')
    expect(wrapper.text()).toContain('Synced')
    expect(wrapper.text()).toContain('Only works on old.acme.com')
    expect(wrapper.text()).toContain('This device or key only')
  })

  it('adds a passkey: options from the API, the browser creates it, the API saves it', async () => {
    const credential = { id: 'cred' } as never
    vi.mocked(createPasskey).mockResolvedValue(credential)
    const add = vi.fn<Add>(async () => passkey({ uid: 'pk_2', name: 'iPhone' }))
    const wrapper = mountCard({ add })
    await flushPromises()

    await button(wrapper, 'Add a passkey')!.trigger('click')
    await flushPromises()

    expect(createPasskey).toHaveBeenCalledWith({ challenge: 'AQID' })
    expect(add).toHaveBeenCalledWith('reg_1', credential)
    expect(wrapper.text()).toContain('iPhone added.')
  })

  it('asks the user to sign in again when the last sign-in is too old', async () => {
    const options = vi.fn<Options>(async () => {
      throw new ApiError('reauthentication_required', 403)
    })
    const wrapper = mountCard({ options })
    await flushPromises()

    await button(wrapper, 'Add a passkey')!.trigger('click')
    await flushPromises()
    await button(wrapper, 'Sign in again')!.trigger('click')

    expect(wrapper.emitted('reauthenticate')).toHaveLength(1)
  })

  it('says nothing when the user cancels the browser prompt', async () => {
    vi.mocked(createPasskey).mockRejectedValue(new DOMException('cancelled', 'NotAllowedError'))
    const wrapper = mountCard()
    await flushPromises()

    await button(wrapper, 'Add a passkey')!.trigger('click')
    await flushPromises()

    expect(wrapper.find('[role="alert"]').exists()).toBe(false)
    expect(wrapper.text()).not.toContain("couldn't")
  })

  it('stays hidden while passkeys are off and the user has none, but keeps existing ones removable', async () => {
    const hidden = mountCard({ available: false, list: vi.fn<List>(async () => []) })
    await flushPromises()
    expect(hidden.text()).toBe('')

    const existing = mountCard({ available: false })
    await flushPromises()
    expect(existing.text()).toContain('Passkeys are turned off here.')
    expect(button(existing, 'Add a passkey')).toBeUndefined()
    expect(button(existing, 'Remove')).toBeDefined()
  })
})
