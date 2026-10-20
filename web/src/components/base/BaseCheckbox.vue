<script setup lang="ts">
import { computed, useId } from 'vue'
import Checkbox from 'openvue/checkbox'

const props = withDefaults(
  defineProps<{
    label: string
    hint?: string
    disabled?: boolean
  }>(),
  {
    disabled: false,
  },
)

const model = defineModel<boolean>({ default: false })

const id = useId()
const hintId = `${id}-hint`

const passThrough = computed(() => ({
  root: { class: 'relative inline-flex size-5 shrink-0' },
  input: {
    class: [
      'peer absolute inset-0 z-10 m-0 size-full appearance-none opacity-0',
      props.disabled ? 'cursor-not-allowed' : 'cursor-pointer',
    ],
  },
  box: {
    class: [
      'flex size-5 items-center justify-center rounded-sm border transition-colors motion-reduce:transition-none',
      'peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-primary',
      model.value ? 'border-primary bg-primary text-on-primary' : 'border-text-muted bg-bg',
      props.disabled ? 'opacity-50' : 'peer-hover:border-primary',
    ],
  },
  icon: { class: 'size-3', 'aria-hidden': 'true' },
}))
</script>

<template>
  <div class="flex items-start gap-3">
    <Checkbox
      v-model="model"
      :input-id="id"
      binary
      :disabled="disabled"
      :aria-describedby="hint ? hintId : undefined"
      :pt="passThrough"
    />
    <div class="flex flex-col gap-1">
      <label :for="id" class="text-sm font-medium" :class="disabled ? 'text-text-disabled' : 'cursor-pointer'">
        {{ label }}
      </label>
      <p v-if="hint" :id="hintId" class="text-xs text-text-muted">{{ hint }}</p>
    </div>
  </div>
</template>
