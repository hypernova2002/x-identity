import { z } from 'zod'

import { formatList, i18n } from '@/i18n'
import { apiBaseUrl } from '@/utils/customDomain'

export type ErrorParams = Record<string, unknown>

export interface ApiErrorDetail {
  field: string
  code: string
  params?: ErrorParams
}

interface ApiErrorBody {
  error: {
    code: string
    reason?: string | null
    params?: ErrorParams
    details?: ApiErrorDetail[]
  }
}

interface ApiErrorOptions {
  reason?: string | null
  params?: ErrorParams
  details?: ApiErrorDetail[]
}

/** Params as messages use them: lists read as the current language writes them. */
function messageParams(params: ErrorParams = {}): Record<string, unknown> {
  return Object.fromEntries(Object.entries(params).map(([name, value]) => [name, Array.isArray(value) ? formatList(value.map(String)) : value]))
}

/** The message for an error's code, or for its reason when we have one; the API's own message isn't used. */
export function errorMessage(code: string, reason?: string | null, params?: ErrorParams): string {
  const { t, te } = i18n.global
  if (reason && te(`errors.reasons.${reason}`)) return t(`errors.reasons.${reason}`, messageParams(params))
  return te(`errors.codes.${code}`) ? t(`errors.codes.${code}`) : t('errors.codes.unknown')
}

/** The message for a field-level problem, from its code. */
export function detailMessage(detail: ApiErrorDetail): string {
  const { t, te } = i18n.global
  const params = messageParams(detail.params)
  const count = typeof detail.params?.count === 'number' ? detail.params.count : undefined
  if (!te(`errors.details.${detail.code}`)) return t('errors.details.invalid')
  return count === undefined ? t(`errors.details.${detail.code}`, params) : t(`errors.details.${detail.code}`, params, count)
}

export class ApiError extends Error {
  readonly code: string
  readonly status: number
  readonly reason: string | null
  readonly params: ErrorParams
  readonly details: ApiErrorDetail[]

  constructor(code: string, status: number, { reason = null, params = {}, details = [] }: ApiErrorOptions = {}) {
    super(errorMessage(code, reason, params))
    this.name = 'ApiError'
    this.code = code
    this.status = status
    this.reason = reason
    this.params = params
    this.details = details
  }

  fieldError(field: string): string | undefined {
    const detail = this.details.find((candidate) => candidate.field === field)
    return detail && detailMessage(detail)
  }
}

export interface AuthHandlers {
  getAccessToken: () => string | null
  refreshAccessToken: () => Promise<boolean>
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'
  body?: unknown
  query?: Record<string, string | number | readonly string[] | undefined>
  authenticated?: boolean
  /** A token other than the console session's, e.g. the app portal's own access token. */
  accessToken?: string
}

export interface Page<T> {
  items: T[]
  /** When `capped`, a lower bound: at least this many match. */
  total: number
  perPage: number
  /** The server stopped counting; ask with `exactCount` for the real total. */
  capped?: boolean
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
    typeof (error as { code?: unknown }).code === 'string'
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
  const url = `${apiBaseUrl()}${path}`
  if (!query) return url

  const search = new URLSearchParams()
  for (const [key, value] of Object.entries(query)) {
    if (Array.isArray(value)) value.forEach((item) => search.append(`${key}[]`, item))
    else if (value !== undefined && value !== '') search.set(key, String(value))
  }
  const queryString = search.toString()
  return queryString === '' ? url : `${url}?${queryString}`
}

async function send(path: string, options: RequestOptions): Promise<Response> {
  const headers = new Headers({ Accept: 'application/json' })
  if (options.body !== undefined) headers.set('Content-Type', 'application/json')

  const accessToken = options.accessToken ?? (options.authenticated ? authHandlers?.getAccessToken() : null)
  if (accessToken) headers.set('Authorization', `Bearer ${accessToken}`)

  try {
    return await fetch(buildUrl(path, options.query), {
      method: options.method ?? 'GET',
      headers,
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
    })
  } catch {
    throw new ApiError('network_error', 0)
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
      throw new ApiError(body.error.code, response.status, { reason: body.error.reason, params: body.error.params, details: body.error.details })
    }
    throw new ApiError('internal_error', response.status)
  }

  return { response, body }
}

export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { body } = await sendWithRefresh(path, options)
  return body as T
}

/** A page of a list endpoint. Items are checked against `schema`, so a changed API fails loudly here. */
export async function apiPage<T>(path: string, schema: z.ZodType<T>, options: RequestOptions = {}): Promise<Page<T>> {
  const { response, body } = await sendWithRefresh(path, options)
  const parsed = z.array(schema).safeParse(body ?? [])
  if (!parsed.success) throw new ApiError('invalid_response', response.status)
  const items = parsed.data

  return {
    items,
    total: Number(response.headers.get('Total') ?? items.length),
    perPage: Number(response.headers.get('Per-Page') ?? items.length),
    capped: response.headers.get('Total-Capped') === 'true',
  }
}
