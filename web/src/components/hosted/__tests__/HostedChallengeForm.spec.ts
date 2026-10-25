import { describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import HostedChallengeForm from '../HostedChallengeForm.vue'
import type { SignInChallenge } from '@/types/api'

vi.mock('@/utils/webauthn', async (original) => ({ ...(await original<typeof import('@/utils/webauthn')>()), passkeysSupported: () => true }))

function mountForm(challenge: SignInChallenge) {
  return mount(HostedChallengeForm, {
    props: { challenge, enrollment: null, error: null, loading: false },
    global: { plugins: [[OpenVue, { unstyled: true }]] },
  })
}

const labels = (wrapper: ReturnType<typeof mountForm>) => wrapper.findAll('button').map((button) => button.text())

describe('HostedChallengeForm', () => {
  it('asks only for the passkey when that is the challenge', async () => {
    const wrapper = mountForm({ challenge: 'passkey', session: 's', mfa_methods: ['passkey'] })

    expect(wrapper.find('input').exists()).toBe(false)
    expect(labels(wrapper)).toEqual(['Use your passkey', 'Start over'])
    await wrapper.findAll('button')[0]!.trigger('click')
    expect(wrapper.emitted('passkey')).toHaveLength(1)
  })

  it('offers the passkey as an alternative to a code when the challenge allows it', () => {
    expect(labels(mountForm({ challenge: 'otp', session: 's', mfa_methods: ['otp', 'passkey'] }))).toContain('Use your passkey instead')
    expect(labels(mountForm({ challenge: 'otp', session: 's', mfa_methods: ['otp'] }))).not.toContain('Use your passkey instead')
  })

  it('asks the user to create a passkey for passkey_setup', async () => {
    const wrapper = mountForm({ challenge: 'passkey_setup', session: 's' })

    expect(wrapper.find('input').exists()).toBe(false)
    expect(labels(wrapper)).toEqual(['Create a passkey', 'Start over'])
    await wrapper.findAll('button')[0]!.trigger('click')
    expect(wrapper.emitted('passkey')).toHaveLength(1)
  })
})
