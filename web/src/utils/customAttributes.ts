import type { CustomAttributeInput } from '@/services/project'
import type { AttributeDefinition } from '@/types/api'

/** Attribute values as edited in a form, before conversion to API values. */
export type AttributeDraft = Record<string, string | boolean>

/**
 * Converts form values to API values: numbers become numbers, empty fields are left out (or sent
 * as null to clear them when `clearEmpty` is set), and anything that isn't a number is sent as
 * typed so the API reports it.
 */
export function toCustomAttributes(
  definitions: readonly AttributeDefinition[],
  draft: AttributeDraft,
  { clearEmpty = false } = {},
): CustomAttributeInput {
  const result: CustomAttributeInput = {}

  for (const definition of definitions) {
    const value = draft[definition.key]
    if (value === undefined) continue

    if (value === '') {
      if (clearEmpty) result[definition.key] = null
      continue
    }

    if (definition.data_type === 'number' && typeof value === 'string' && value.trim() !== '' && !Number.isNaN(Number(value))) {
      result[definition.key] = Number(value)
    } else {
      result[definition.key] = value
    }
  }

  return result
}
