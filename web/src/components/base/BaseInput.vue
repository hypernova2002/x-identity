<script setup lang="ts">
import { computed, useId } from 'vue'
import InputText from 'openvue/inputtext'

const props = withDefaults(
  defineProps<{
    label: string
    type?: 'text' | 'email' | 'password' | 'search' | 'tel' | 'url' | 'number' | 'date'
    autocomplete?: string
    placeholder?: string
    /** A magnifier inside the field, for search boxes. */
    icon?: 'search'
    inputmode?: 'text' | 'numeric' | 'email'
    hint?: string
    error?: string
    required?: boolean
    disabled?: boolean
  }>(),
  {
    type: 'text',
    required: false,
    disabled: false,
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
      'h-10 w-full rounded-md border bg-bg pr-3 text-sm text-text',
      props.icon ? 'pl-9' : 'pl-3',
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
      <span v-if="required" class="text-text-muted">(required)</span>
    </label>
    <div class="relative">
      <svg
        v-if="icon === 'search'"
        aria-hidden="true"
        viewBox="0 0 20 20"
        class="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-text-muted"
        fill="none"
        stroke="currentColor"
        stroke-width="1.75"
        stroke-linecap="round"
      >
        <circle cx="9" cy="9" r="5.5" />
        <path d="M13 13l3.5 3.5" />
      </svg>
      <InputText
        :id="id"
        v-model="model"
        :type="type"
        :placeholder="placeholder"
        :autocomplete="autocomplete"
        :inputmode="inputmode"
        :required="required"
        :disabled="disabled"
        :invalid="Boolean(error)"
        :aria-describedby="describedBy"
        :pt="passThrough"
      />
    </div>
    <p v-if="hint" :id="hintId" class="text-xs text-text-muted">{{ hint }}</p>
    <p v-if="error" :id="errorId" class="text-xs font-medium text-danger">
      Error: {{ error }}
    </p>
  </div>
</template>
