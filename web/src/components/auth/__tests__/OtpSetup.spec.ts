import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'

import OtpSetup from '../OtpSetup.vue'
import type { MfaEnrollment } from '@/types/api'

const enrollment = (overrides: Partial<MfaEnrollment> = {}): MfaEnrollment => ({
  otp_type: 'totp',
  digits: 6,
  step_seconds: 30,
  secret: 'JBSWY3DPEHPK3PXPJBSW',
  provisioning_uri: 'otpauth://totp/x',
  qr_code_svg: '<svg xmlns="http://www.w3.org/2000/svg"></svg>',
  ...overrides,
})

describe('OtpSetup', () => {
  it('shows the QR code, and the key in groups of four for typing in', () => {
    const wrapper = mount(OtpSetup, { props: { enrollment: enrollment() } })

    expect(wrapper.get('img').attributes('alt')).toBe('QR code for your authenticator app')
    expect(wrapper.get('img').attributes('src')).toMatch(/^data:image\/svg\+xml;utf8,%3Csvg/)
    expect(wrapper.get('code').text()).toBe('JBSW Y3DP EHPK 3PXP JBSW')
    expect(wrapper.text()).toContain('enter the 6-digit code it shows')
  })

  it('warns that some apps only support 6 digits and 30 seconds', () => {
    expect(mount(OtpSetup, { props: { enrollment: enrollment() } }).text()).not.toContain('Some apps')
    expect(mount(OtpSetup, { props: { enrollment: enrollment({ digits: 8 }) } }).text()).toContain('Uses 8 digits and 30-second steps')
  })

  it('explains hardware tokens for HOTP', () => {
    const wrapper = mount(OtpSetup, { props: { enrollment: enrollment({ otp_type: 'hotp', step_seconds: null }) } })

    expect(wrapper.get('img').attributes('alt')).toBe('QR code for your hardware token')
    expect(wrapper.text()).toContain('hardware token')
    expect(wrapper.text()).not.toContain('Some apps')
  })
})
