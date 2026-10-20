<script setup lang="ts" generic="T extends string">
import { computed, useId } from 'vue'
import Select from 'openvue/select'

import type { SelectOption } from './types'

const props = withDefaults(
  defineProps<{
    label: string
    options: readonly SelectOption<T>[]
    hideLabel?: boolean
    hint?: string
    error?: string
    disabled?: boolean
  }>(),
  {
    hideLabel: false,
    disabled: false,
  },
)

const model = defineModel<T>({ required: true })

const id = useId()
const hintId = `${id}-hint`
const errorId = `${id}-error`
const labelId = `${id}-label`

const optionList = computed(() => [...props.options])

const describedBy = computed(() => {
  const ids = [props.hint ? hintId : null, props.error ? errorId : null].filter(Boolean)
  return ids.length > 0 ? ids.join(' ') : undefined
})

interface OptionContext {
  context: { selected: boolean; focused: boolean }
}

const passThrough = computed(() => ({
  root: {
    class: [
      'relative inline-flex h-10 w-full cursor-pointer items-center rounded-md border bg-bg text-sm',
      'has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-primary',
      props.disabled ? 'cursor-not-allowed bg-bg-subtle text-text-disabled' : '',
      props.error ? 'border-danger' : 'border-border hover:border-text-muted',
    ],
  },
  label: { class: 'flex-1 truncate px-3 outline-none' },
  dropdown: { class: 'flex h-full items-center px-3 text-text-muted' },
  dropdownIcon: { class: 'size-3', 'aria-hidden': 'true' },
  overlay: { class: 'mt-1 rounded-md border border-border bg-bg shadow-md' },
  listContainer: { class: 'max-h-64 overflow-auto' },
  list: { class: 'py-1' },
  option: ({ context }: OptionContext) => ({
    class: [
      'flex cursor-pointer items-center gap-2 px-3 py-2 text-sm',
      context.selected ? 'bg-primary-subtle font-medium text-primary-active' : 'text-text',
      context.focused && !context.selected ? 'bg-bg-subtle' : '',
    ],
  }),
}))
</script>

<template>
  <div class="flex flex-col gap-2">
    <span :id="labelId" class="text-sm font-medium" :class="{ 'sr-only': hideLabel }">{{ label }}</span>
    <Select
      v-model="model"
      :options="optionList"
      option-label="label"
      option-value="value"
      :disabled="disabled"
      :invalid="Boolean(error)"
      :aria-labelledby="labelId"
      :aria-describedby="describedBy"
      :pt="passThrough"
    />
    <p v-if="hint" :id="hintId" class="text-xs text-text-muted">{{ hint }}</p>
    <p v-if="error" :id="errorId" class="text-xs font-medium text-danger">Error: {{ error }}</p>
  </div>
</template>
