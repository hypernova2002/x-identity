<script setup lang="ts">
import { computed } from 'vue'
import Button from 'openvue/button'

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger'
type ButtonSize = 'sm' | 'md' | 'lg'

const props = withDefaults(
  defineProps<{
    label: string
    variant?: ButtonVariant
    size?: ButtonSize
    type?: 'button' | 'submit' | 'reset'
    loading?: boolean
    disabled?: boolean
  }>(),
  {
    variant: 'primary',
    size: 'md',
    type: 'button',
    loading: false,
    disabled: false,
  },
)

const emit = defineEmits<{
  click: [event: MouseEvent]
}>()

const variantClasses: Record<ButtonVariant, string> = {
  primary:
    'border-transparent bg-primary text-on-primary enabled:hover:bg-primary-hover enabled:active:bg-primary-active',
  secondary:
    'border-border bg-bg text-text enabled:hover:bg-bg-subtle enabled:active:bg-border',
  ghost:
    'border-transparent bg-transparent text-primary enabled:hover:bg-primary-subtle enabled:active:text-primary-active',
  danger:
    'border-transparent bg-danger text-on-primary enabled:hover:bg-danger-hover enabled:active:bg-danger-active',
}

const sizeClasses: Record<ButtonSize, string> = {
  sm: 'h-8 px-3 text-sm',
  md: 'h-10 px-4 text-sm',
  lg: 'h-12 px-6 text-base',
}

const passThrough = computed(() => ({
  root: {
    class: [
      'inline-flex items-center justify-center gap-2 rounded-md border font-medium',
      'transition-colors motion-reduce:transition-none',
      'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary',
      'disabled:cursor-not-allowed disabled:border-border disabled:bg-bg-subtle disabled:text-text-disabled',
      variantClasses[props.variant],
      sizeClasses[props.size],
    ],
  },
  loadingIcon: {
    class: 'size-4 animate-spin motion-reduce:animate-none',
    'aria-hidden': 'true',
  },
}))
</script>

<template>
  <Button
    :label="label"
    :type="type"
    :loading="loading"
    :disabled="disabled || loading"
    :aria-busy="loading || undefined"
    :pt="passThrough"
    @click="emit('click', $event)"
  />
</template>
