import { describe, expect, it } from 'vitest'

import { toCustomAttributes } from '../customAttributes'
import type { AttributeDefinition } from '@/types/api'

function definition(key: string, dataType: AttributeDefinition['data_type']): AttributeDefinition {
  return {
    uid: `attr_${key}`,
    key,
    label: key,
    data_type: dataType,
    required: false,
    max_length: null,
    user_editable: true,
    include_in_token: false,
    created_at: '2026-10-21T00:00:00Z',
    updated_at: '2026-10-21T00:00:00Z',
  }
}

const definitions = [definition('nickname', 'string'), definition('age', 'number'), definition('newsletter', 'boolean')]

describe('toCustomAttributes', () => {
  it('converts numbers and keeps other values as typed', () => {
    expect(toCustomAttributes(definitions, { nickname: 'Cas', age: '30', newsletter: true })).toEqual({
      nickname: 'Cas',
      age: 30,
      newsletter: true,
    })
  })

  it('sends non-numeric text for number attributes unchanged, so the API reports it', () => {
    expect(toCustomAttributes(definitions, { age: 'thirty' })).toEqual({ age: 'thirty' })
  })

  it('leaves out empty fields', () => {
    expect(toCustomAttributes(definitions, { nickname: '' })).toEqual({})
  })

  it('clears empty fields when asked', () => {
    expect(toCustomAttributes(definitions, { nickname: '' }, { clearEmpty: true })).toEqual({ nickname: null })
  })

  it('ignores values for attributes that no longer exist', () => {
    expect(toCustomAttributes(definitions, { shoe_size: '42' })).toEqual({})
  })
})
