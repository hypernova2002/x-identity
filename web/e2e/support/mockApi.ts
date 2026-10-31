import { expect, type Page, type Route } from '@playwright/test'

import { API_ORIGIN, APP_ORIGIN } from './origins'

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'

export interface MockReply {
  status?: number
  body?: unknown
  headers?: Record<string, string>
}

export interface MockRequest {
  method: string
  path: string
  query: URLSearchParams
  body: unknown
  headers: Record<string, string>
  /** The values of the handler's `:name` path segments. */
  params: Record<string, string>
}

type Responder = MockReply | ((request: MockRequest) => MockReply)

interface Handler {
  method: Method
  path: string
  pattern: RegExp
  names: string[]
  respond: Responder
}

const CORS_HEADERS = {
  'access-control-allow-origin': APP_ORIGIN,
  'access-control-expose-headers': 'Total, Per-Page, Total-Capped',
}

/** An API error in the backend's shape. */
export function apiError(status: number, code: string, error: { reason?: string; params?: object; details?: object[] } = {}): MockReply {
  return { status, body: { error: { code, reason: error.reason ?? null, message: code, params: error.params ?? {}, details: error.details ?? [] } } }
}

/** A page of a list endpoint, with the headers the backend sends. */
export function listPage(items: unknown[], { total = items.length, perPage = 25 } = {}): MockReply {
  return { body: items, headers: { Total: String(total), 'Per-Page': String(perPage) } }
}

/**
 * Answers the app's API requests in a test. Each test registers the endpoints it expects; a request
 * nothing answers fails the test when it ends, so unexpected calls never pass silently.
 */
export class MockApi {
  readonly requests: MockRequest[] = []
  readonly unhandled: string[] = []
  private readonly handlers: Handler[] = []

  constructor(private readonly page: Page) {}

  async install() {
    await this.page.route(`${API_ORIGIN}/**`, (route) => this.handle(route))
  }

  /** Answers `method path`, where `:name` segments match any value. A later handler for the same request wins. */
  on(method: Method, path: string, respond: Responder): this {
    const names: string[] = []
    const source = path.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/:(\w+)/g, (_, name: string) => {
      names.push(name)
      return '([^/]+)'
    })
    this.handlers.push({ method, path, pattern: new RegExp(`^${source}$`), names, respond })
    return this
  }

  /** Requests answered by the handler registered for `method path`. */
  calls(method: Method, path: string): MockRequest[] {
    const handler = this.handlers.findLast((candidate) => candidate.method === method && candidate.path === path)
    if (!handler) throw new Error(`No handler for ${method} ${path}`)
    return this.requests.filter((request) => request.method === method && handler.pattern.test(request.path))
  }

  /** The latest request to `method path`, once at least `count` have been made. */
  async lastCall(method: Method, path: string, count = 1): Promise<MockRequest> {
    await expect.poll(() => this.calls(method, path).length, { message: `${method} ${path} requests` }).toBeGreaterThanOrEqual(count)
    return this.calls(method, path).at(-1)!
  }

  private async handle(route: Route) {
    const request = route.request()
    if (request.method() === 'OPTIONS') {
      return route.fulfill({
        status: 204,
        headers: {
          ...CORS_HEADERS,
          'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE',
          'access-control-allow-headers': 'Authorization, Content-Type, Accept-Language',
        },
      })
    }

    const url = new URL(request.url())
    const handler = this.handlers.findLast((candidate) => candidate.method === request.method() && candidate.pattern.test(url.pathname))
    const match = handler?.pattern.exec(url.pathname)
    const mockRequest: MockRequest = {
      method: request.method(),
      path: url.pathname,
      query: url.searchParams,
      body: request.postDataJSON() ?? null,
      headers: await request.allHeaders(),
      params: Object.fromEntries(handler?.names.map((name, index) => [name, decodeURIComponent(match?.[index + 1] ?? '')]) ?? []),
    }
    this.requests.push(mockRequest)

    if (!handler) this.unhandled.push(`${request.method()} ${url.pathname}`)
    const reply = !handler ? apiError(501, 'not_mocked') : typeof handler.respond === 'function' ? handler.respond(mockRequest) : handler.respond
    const status = reply.status ?? (reply.body === undefined ? 204 : 200)
    await route.fulfill({
      status,
      headers: { ...CORS_HEADERS, ...reply.headers, ...(reply.body === undefined ? {} : { 'content-type': 'application/json' }) },
      body: reply.body === undefined ? '' : JSON.stringify(reply.body),
    })
  }
}
