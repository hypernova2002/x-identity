<script setup lang="ts">
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import type { ApiError } from '@/services/http'
import type { AttributeDefinition } from '@/types/api'
import type { AttributeDraft } from '@/utils/customAttributes'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()

defineProps<{
  definitions: readonly AttributeDefinition[]
  error?: ApiError | null
}>()

const values = defineModel<AttributeDraft>({ required: true })

function hint(definition: AttributeDefinition): string | undefined {
  if (definition.data_type === 'date') return t('project.customAttributeFields.aDateLike')
  if (definition.max_length) return t('project.customAttributeFields.atMostCharacters', { maxLength: definition.max_length })
  return undefined
}
</script>

<template>
  <fieldset v-if="definitions.length > 0" class="flex flex-col gap-4">
    <legend class="mb-2 text-sm font-semibold">{{ $t('project.customAttributeFields.attributes') }}</legend>
    <template v-for="definition in definitions" :key="definition.uid">
      <BaseCheckbox
        v-if="definition.data_type === 'boolean'"
        :model-value="values[definition.key] === true"
        :label="definition.label"
        @update:model-value="(checked: boolean) => (values = { ...values, [definition.key]: checked })"
      />
      <BaseInput
        v-else
        :model-value="String(values[definition.key] ?? '')"
        :label="definition.label"
        :type="definition.data_type === 'number' ? 'number' : 'text'"
        :required="definition.required"
        :hint="hint(definition)"
        :error="error?.fieldError(`custom_attributes.${definition.key}`)"
        @update:model-value="(value: string) => (values = { ...values, [definition.key]: value })"
      />
    </template>
  </fieldset>
</template>
