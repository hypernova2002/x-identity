// Labels for the shared option lists in utils/options.ts, keyed by the value each option sends.
export default {
  identityProviderKind: {
    google: 'Google',
    apple: 'Apple',
    oidc: 'Other OpenID Connect provider',
    saml: "SAML 2.0 (a company's identity provider)",
  },
  accountRole: { owner: 'Owner', admin: 'Admin', member: 'Member' },
  projectRole: { admin: 'Admin', developer: 'Developer', viewer: 'Viewer' },
  mfaRequirement: {
    off: 'Off — never ask for a code',
    optional: 'Optional — users choose',
    required: 'Required — everyone must use MFA',
  },
  passkeys: {
    off: 'Off',
    optional: 'Optional: users can add passkeys',
    required: 'Required: sign-ins must use a passkey',
  },
  signingAlgorithm: { ES256: 'ES256 (ECDSA P-256)', RS256: 'RS256 (RSA PKCS#1)', PS256: 'PS256 (RSA-PSS)' },
  appClientType: {
    public: 'Public — browser or mobile app, no secret',
    confidential: 'Confidential — server-side app with a secret',
  },
  attributeDataType: { string: 'Text', number: 'Number', boolean: 'Yes / no', date: 'Date' },
  otpMethod: {
    totp: 'Authenticator app (time-based codes)',
    hotp: 'Hardware token (counter-based codes)',
  },
  userStatus: { active: 'Active', disabled: 'Disabled' },
  yesNo: { true: 'Yes', false: 'No' },
}
