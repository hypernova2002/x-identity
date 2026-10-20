import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import { configureAuth } from '@/services/http'
import { authService } from '@/services/auth'
import { meService } from '@/services/account'
import type { AccountSummary, Me, TokenSet } from '@/types/api'

const SESSION_KEY = 'x-identity.session'
const LAST_ACCOUNT_KEY = 'x-identity.last-account'

interface PersistedSession {
  account: AccountSummary
  refreshToken: string
}

function readStorage<T>(key: string): T | null {
  try {
    const value = localStorage.getItem(key)
    return value ? (JSON.parse(value) as T) : null
  } catch {
    return null
  }
}

function writeStorage(key: string, value: unknown) {
  try {
    if (value === null) localStorage.removeItem(key)
    else localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // Storage can be unavailable (private mode, blocked site data); the session then lasts only for this page load.
  }
}

export const useSessionStore = defineStore('session', () => {
  const account = ref<AccountSummary | null>(null)
  const accessToken = ref<string | null>(null)
  const refreshToken = ref<string | null>(null)
  const me = ref<Me | null>(null)

  const isAuthenticated = computed(() => accessToken.value !== null && account.value !== null)
  const isAccountAdmin = computed(() => me.value?.role === 'owner' || me.value?.role === 'admin')

  let pendingRefresh: Promise<boolean> | null = null

  function persist() {
    const session = account.value && refreshToken.value ? { account: account.value, refreshToken: refreshToken.value } : null
    writeStorage(SESSION_KEY, session)
  }

  function clear() {
    account.value = null
    accessToken.value = null
    refreshToken.value = null
    me.value = null
    persist()
  }

  function start(signedInAccount: AccountSummary, tokens: TokenSet) {
    account.value = signedInAccount
    accessToken.value = tokens.access_token
    refreshToken.value = tokens.refresh_token
    writeStorage(LAST_ACCOUNT_KEY, signedInAccount.slug)
    persist()
  }

  function rememberAccount(slug: string) {
    writeStorage(LAST_ACCOUNT_KEY, slug)
  }

  function lastAccountSlug(): string | null {
    return readStorage<string>(LAST_ACCOUNT_KEY)
  }

  async function refreshTokens(): Promise<boolean> {
    if (!account.value || !refreshToken.value) return false

    pendingRefresh ??= authService
      .refresh(account.value.uid, refreshToken.value)
      .then((tokens) => {
        accessToken.value = tokens.access_token
        refreshToken.value = tokens.refresh_token
        persist()
        return true
      })
      .catch(() => {
        clear()
        return false
      })
      .finally(() => {
        pendingRefresh = null
      })

    return pendingRefresh
  }

  async function restore(): Promise<boolean> {
    if (isAuthenticated.value) return true

    const persisted = readStorage<PersistedSession>(SESSION_KEY)
    if (!persisted) return false

    account.value = persisted.account
    refreshToken.value = persisted.refreshToken
    return refreshTokens()
  }

  async function loadMe(): Promise<Me | null> {
    if (!account.value) return null

    me.value = await meService.get(account.value.uid)
    return me.value
  }

  async function signOut() {
    if (account.value && refreshToken.value) {
      await authService.signOut(account.value.uid, refreshToken.value).catch(() => null)
    }
    clear()
  }

  configureAuth({
    getAccessToken: () => accessToken.value,
    refreshAccessToken: refreshTokens,
  })

  return {
    account,
    me,
    isAuthenticated,
    isAccountAdmin,
    lastAccountSlug,
    start,
    rememberAccount,
    restore,
    loadMe,
    signOut,
    clear,
  }
})
