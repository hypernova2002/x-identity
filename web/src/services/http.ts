export interface ApiErrorDetail {
  field: string
  message: string
}

interface ApiErrorBody {
  error: {
    code: string
    message: string
    details: ApiErrorDetail[]
  }
}

export class ApiError extends Error {
  readonly code: string
  readonly status: number
  readonly details: ApiErrorDetail[]

  constructor(code: string, message: string, status: number, details: ApiErrorDetail[] = []) {
    super(message)
    this.name = 'ApiError'
    this.code = code
    this.status = status
    this.details = details
  }

  fieldError(field: string): string | undefined {
    return this.details.find((detail) => detail.field === field)?.message
  }
}

export interface AuthHandlers {
  getAccessToken: () => string | null
  refreshAccessToken: () => Promise<boolean>
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'
  body?: unknown
  query?: Record<string, string | number | undefined>
  authenticated?: boolean
}

export interface Page<T> {
  items: T[]
  total: number
  perPage: number
}

let authHandlers: AuthHandlers | null = null

export function configureAuth(handlers: AuthHandlers | null) {
  authHandlers = handlers
}

function isApiErrorBody(value: unknown): value is ApiErrorBody {
  if (typeof value !== 'object' || value === null || !('error' in value)) return false

  const error = (value as { error: unknown }).error
  return (
    typeof error === 'object' &&
    error !== null &&
    typeof (error as { code?: unknown }).code === 'string' &&
    typeof (error as { message?: unknown }).message === 'string'
  )
}

async function parseJson(response: Response): Promise<unknown> {
  const text = await response.text()
  if (text === '') return null

  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

function buildUrl(path: string, query: RequestOptions['query']): string {
  const url = `${import.meta.env.VITE_API_BASE_URL}${path}`
  if (!query) return url

  const search = new URLSearchParams()
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== '') search.set(key, String(value))
  }
  const queryString = search.toString()
  return queryString === '' ? url : `${url}?${queryString}`
}

async function send(path: string, options: RequestOptions): Promise<Response> {
  const headers = new Headers({ Accept: 'application/json' })
  if (options.body !== undefined) headers.set('Content-Type', 'application/json')

  const accessToken = options.authenticated ? authHandlers?.getAccessToken() : null
  if (accessToken) headers.set('Authorization', `Bearer ${accessToken}`)

  try {
    return await fetch(buildUrl(path, options.query), {
      method: options.method ?? 'GET',
      headers,
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
    })
  } catch {
    throw new ApiError(
      'network_error',
      "We couldn't reach the server. Check your connection and try again.",
      0,
    )
  }
}

async function sendWithRefresh(path: string, options: RequestOptions): Promise<{ response: Response; body: unknown }> {
  let response = await send(path, options)
  let body = await parseJson(response)

  const tokenRejected = response.status === 401 && isApiErrorBody(body) && body.error.code === 'invalid_token'
  if (options.authenticated && tokenRejected && authHandlers && (await authHandlers.refreshAccessToken())) {
    response = await send(path, options)
    body = await parseJson(response)
  }

  if (!response.ok) {
    if (isApiErrorBody(body)) {
      throw new ApiError(body.error.code, body.error.message, response.status, body.error.details ?? [])
    }
    throw new ApiError('internal_error', 'An unexpected error occurred.', response.status)
  }

  return { response, body }
}

export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { body } = await sendWithRefresh(path, options)
  return body as T
}

export async function apiPage<T>(path: string, options: RequestOptions = {}): Promise<Page<T>> {
  const { response, body } = await sendWithRefresh(path, options)
  const items = (body ?? []) as T[]

  return {
    items,
    total: Number(response.headers.get('Total') ?? items.length),
    perPage: Number(response.headers.get('Per-Page') ?? items.length),
  }
}
