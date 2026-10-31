import type { Account, AccountSummary, AppClient, AppClientWithSecret, DeviceSession, EndUser, Me, Project, TokenSet } from '@/types/api'

const CREATED_AT = '2026-10-01T09:00:00Z'

export function account(overrides: Partial<Account> = {}): Account {
  return { uid: 'acc_acme', name: 'Acme', slug: 'acme', created_at: CREATED_AT, updated_at: CREATED_AT, ...overrides }
}

export function accountSummary(overrides: Partial<AccountSummary> = {}): AccountSummary {
  const { uid, name, slug } = account()
  return { uid, name, slug, passkeys: false, ...overrides }
}

export function me(overrides: Partial<Me> = {}): Me {
  return {
    uid: 'usr_olive',
    name: 'Olive Owner',
    email: 'olive@acme.test',
    role: 'owner',
    status: 'active',
    email_verified: true,
    mfa_enabled: false,
    last_sign_in_at: CREATED_AT,
    created_at: CREATED_AT,
    updated_at: CREATED_AT,
    password_changed_at: CREATED_AT,
    locale: null,
    otp_method: 'totp',
    passkeys_available: false,
    account: account(),
    ...overrides,
  }
}

export function tokens(overrides: Partial<TokenSet> = {}): TokenSet {
  return { access_token: 'access-token', refresh_token: 'refresh-token', token_type: 'Bearer', expires_in: 900, ...overrides }
}

export function project(overrides: Partial<Project> = {}): Project {
  return {
    uid: 'prj_shop',
    name: 'Shop',
    allow_self_sign_up: true,
    confirm_sign_up_url: null,
    reset_password_url: null,
    accept_invitation_url: null,
    token_issuer: 'http://api.test/v1/accounts/acc_acme/projects/prj_shop',
    created_at: CREATED_AT,
    updated_at: CREATED_AT,
    ...overrides,
  }
}

export function appClient(overrides: Partial<AppClientWithSecret> = {}): AppClientWithSecret {
  const client: AppClient = {
    uid: 'app_web',
    name: 'Web shop',
    client_type: 'public',
    machine: false,
    allowed_origins: [],
    redirect_uris: [],
    post_logout_redirect_uris: [],
    launch_url: null,
    enabled: true,
    token_requests_per_minute: null,
    created_at: CREATED_AT,
    updated_at: CREATED_AT,
  }
  return { ...client, client_secret: null, ...overrides }
}

export function endUser(overrides: Partial<EndUser> = {}): EndUser {
  return {
    uid: 'eu_casey',
    email: 'casey@shop.test',
    name: 'Casey Customer',
    status: 'active',
    email_verified: true,
    mfa_enabled: false,
    invitation_pending: false,
    groups: [],
    custom_attributes: {},
    locale: null,
    last_sign_in_at: null,
    created_at: CREATED_AT,
    updated_at: CREATED_AT,
    ...overrides,
  }
}

export function deviceSession(overrides: Partial<DeviceSession> = {}): DeviceSession {
  return {
    uid: 'dev_mac',
    device_name: 'Chrome on Mac',
    device_type: 'desktop',
    ip: '81.17.240.1',
    user_agent: 'Mozilla/5.0',
    location: { city: 'Dublin', region: 'Leinster', country_code: 'IE' },
    amr: ['pwd'],
    created_at: CREATED_AT,
    last_seen_at: CREATED_AT,
    current: false,
    ...overrides,
  }
}
