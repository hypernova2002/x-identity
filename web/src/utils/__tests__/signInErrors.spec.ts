import { describe, expect, it } from 'vitest'

import { explainSignInError } from '../signInErrors'

describe('explainSignInError', () => {
  it("doesn't say whether the email is registered for wrong credentials", () => {
    const explanation = explainSignInError('invalid_credentials')

    expect(explanation).toContain("doesn't say which")
    expect(explanation).not.toMatch(/no account|not registered|doesn't exist/i)
  })

  it('points to the Access tab when the user is not assigned', () => {
    expect(explainSignInError('app_access_denied')).toContain('Access tab')
  })

  it('returns nothing for unknown codes', () => {
    expect(explainSignInError('something_new')).toBeUndefined()
  })
})
