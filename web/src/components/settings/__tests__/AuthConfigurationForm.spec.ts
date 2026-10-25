import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import AuthConfigurationForm from '../AuthConfigurationForm.vue'
import type { AuthConfiguration } from '@/types/api'

const configuration = (changes: Partial<AuthConfiguration> = {}): AuthConfiguration => ({
  mfa_requirement: 'optional',
  require_email_verification: true,
  notify_new_devices: true,
  passwordless_after_passkey: false,
  password_min_length: 12,
  password_require_uppercase: false,
  password_require_lowercase: false,
  password_require_number: false,
  password_require_symbol: false,
  password_max_age_seconds: null,
  lockout_threshold: 10,
  lockout_window_seconds: 900,
  lockout_duration_seconds: 900,
  access_token_ttl_seconds: 900,
  refresh_token_ttl_seconds: 2592000,
  session_idle_timeout_seconds: null,
  sso_session_ttl_seconds: 86400,
  signing_algorithm: 'ES256',
  signing_key_rotation_seconds: 7776000,
  mfa_max_failed_attempts: 5,
  email_code_max_attempts: 5,
  email_code_max_failures_per_email: 10,
  email_code_max_failures_per_code: 5,
  email_code_failure_window_seconds: 3600,
  otp_method: 'totp',
  otp_digits: 6,
  otp_step_seconds: 30,
  otp_drift_steps: 1,
  otp_hotp_look_ahead: 10,
  passkeys: 'off',
  client_secret_rotation_overlap_seconds: 604800,
  token_requests_per_minute: 120,
  updated_at: '2026-10-25T12:00:00Z',
  ...changes,
})

async function mountForm(loaded: AuthConfiguration, props: Record<string, unknown> = {}) {
  const wrapper = mount(AuthConfigurationForm, {
    props: {
      load: vi.fn<() => Promise<AuthConfiguration>>(async () => loaded),
      save: vi.fn<(changes: Partial<AuthConfiguration>) => Promise<AuthConfiguration>>(async () => loaded),
      emailVerificationHint: '',
      sections: ['sign-in'],
      ...props,
    },
    global: { plugins: [[OpenVue, { unstyled: true }]] },
  })
  await flushPromises()
  return wrapper
}

const noPasswords = (wrapper: Awaited<ReturnType<typeof mountForm>>) =>
  wrapper.findAll('input[type="checkbox"]').find((input) => wrapper.get(`label[for="${input.attributes('id')}"]`).text().startsWith('No passwords'))!

describe('AuthConfigurationForm passkeys', () => {
  beforeEach(() => {
    // OpenVue's Select asks for matchMedia, which jsdom lacks.
    vi.stubGlobal('matchMedia', (query: string) => ({ matches: false, media: query, addEventListener() {}, removeEventListener() {} }))
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('keeps "no passwords" off until passkeys are on', async () => {
    const off = await mountForm(configuration())
    expect(noPasswords(off).attributes('disabled')).toBeDefined()
    expect(off.text()).toContain('Turn passkeys on first.')

    const on = await mountForm(configuration({ passkeys: 'optional' }))
    expect(noPasswords(on).attributes('disabled')).toBeUndefined()
  })

  it("warns when required passkeys can't work yet", async () => {
    expect((await mountForm(configuration({ passkeys: 'required', mfa_requirement: 'off' }))).text()).toContain('Required needs multi-factor authentication')
    expect((await mountForm(configuration({ passkeys: 'required' }), { forProject: true, customDomain: null })).text()).toContain(
      "Required needs the project's verified custom domain",
    )
    expect((await mountForm(configuration({ passkeys: 'required' }), { forProject: true, customDomain: 'login.acme.com' })).text()).not.toContain('Required needs')
  })
})
