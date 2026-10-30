<script setup lang="ts">
import { computed, useId } from 'vue'
import Textarea from 'openvue/textarea'

const props = withDefaults(
  defineProps<{
    label: string
    rows?: number
    hint?: string
    error?: string
    required?: boolean
    disabled?: boolean
    monospace?: boolean
  }>(),
  {
    rows: 4,
    required: false,
    disabled: false,
    monospace: false,
  },
)

const model = defineModel<string>({ default: '' })

const id = useId()
const hintId = `${id}-hint`
const errorId = `${id}-error`

const describedBy = computed(() => {
  const ids = [props.hint ? hintId : null, props.error ? errorId : null].filter(Boolean)
  return ids.length > 0 ? ids.join(' ') : undefined
})

const passThrough = computed(() => ({
  root: {
    class: [
      'w-full rounded-md border bg-bg px-3 py-2 text-sm text-text',
      props.monospace ? 'font-mono text-xs' : '',
      'placeholder:text-text-muted',
      'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary',
      'disabled:cursor-not-allowed disabled:bg-bg-subtle disabled:text-text-disabled',
      props.error ? 'border-danger' : 'border-border hover:enabled:border-text-muted',
    ],
  },
}))
</script>

<template>
  <div class="flex flex-col gap-2">
    <label :for="id" class="text-sm font-medium">
      {{ label }}
      <span v-if="required" class="text-text-muted">{{ $t('base.field.required') }}</span>
    </label>
    <Textarea
      :id="id"
      v-model="model"
      :rows="rows"
      :required="required"
      :disabled="disabled"
      :invalid="Boolean(error)"
      :aria-describedby="describedBy"
      spellcheck="false"
      :pt="passThrough"
    />
    <p v-if="hint" :id="hintId" class="text-xs text-text-muted">{{ hint }}</p>
    <p v-if="error" :id="errorId" class="text-xs font-medium text-danger">
      {{ $t('base.field.error', { message: error }) }}
    </p>
  </div>
</template>
