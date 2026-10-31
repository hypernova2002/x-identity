import { vi } from 'vitest'

export function jsonResponse(body: unknown, status = 200, headers: Record<string, string> = {}) {
  return new Response(body === undefined ? null : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', ...headers } })
}

export interface SentRequest {
  url: string
  method: string
  headers: Headers
  /** JSON bodies parsed; form bodies as an object of their fields. */
  body: unknown
}

/** Replaces `fetch` with a mock that records each request in a form tests can compare. */
export function stubFetch() {
  const fetchMock = vi.fn<typeof fetch>()
  vi.stubGlobal('fetch', fetchMock)

  /** The latest request, or the one at `index`. */
  function sent(index = fetchMock.mock.calls.length - 1): SentRequest {
    const call = fetchMock.mock.calls[index]
    if (!call) throw new Error('No request was sent')
    const [url, init = {}] = call
    const raw = init.body
    const body = raw instanceof URLSearchParams ? Object.fromEntries(raw) : typeof raw === 'string' ? JSON.parse(raw) : (raw ?? null)
    return { url: String(url), method: init.method ?? 'GET', headers: new Headers(init.headers), body }
  }

  return { fetchMock, sent }
}
