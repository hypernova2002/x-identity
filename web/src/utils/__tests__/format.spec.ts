import { describe, expect, it } from 'vitest'

import { formatDuration } from '../format'

describe('formatDuration', () => {
  it('names a single unit', () => {
    expect(formatDuration(900)).toBe('15 minutes')
  })

  it('combines up to two units', () => {
    expect(formatDuration(5400)).toBe('1 hour 30 minutes')
  })

  it('uses singular units', () => {
    expect(formatDuration(86_400)).toBe('1 day')
  })

  it('drops the smallest units beyond two', () => {
    expect(formatDuration(90_061)).toBe('1 day 1 hour')
  })
})
