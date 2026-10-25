/**
 * Whether the app is served on a project's custom domain (e.g. login.acme.com), where only that
 * project's hosted pages run and its endpoints are on the same origin, at the root.
 */
export function onCustomDomain(): boolean {
  const consoleUrl = import.meta.env.VITE_CONSOLE_URL
  return consoleUrl !== undefined && consoleUrl !== '' && window.location.origin !== new URL(consoleUrl).origin
}

/** Where API requests go: x-identity's API, or the custom domain itself. */
export function apiBaseUrl(): string {
  return onCustomDomain() ? '' : import.meta.env.VITE_API_BASE_URL
}

/** The base of a project's public endpoints: under the API, or the root of its custom domain. */
export function projectPath(accountUid: string, projectUid: string): string {
  return onCustomDomain() ? '' : `/v1/accounts/${accountUid}/projects/${projectUid}`
}
