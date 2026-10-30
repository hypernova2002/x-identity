<script setup lang="ts">
import { computed } from 'vue'
import Message from 'openvue/message'
import { useI18n } from 'vue-i18n'

type AlertVariant = 'info' | 'success' | 'warning' | 'danger'

const props = withDefaults(
  defineProps<{
    variant?: AlertVariant
    title?: string
  }>(),
  {
    variant: 'info',
  },
)

const severity = { info: 'info', success: 'success', warning: 'warn', danger: 'error' } as const

const { t } = useI18n()

const borderClasses: Record<AlertVariant, string> = {
  info: 'border-info',
  success: 'border-success',
  warning: 'border-warning',
  danger: 'border-danger',
}

const passThrough = computed(() => ({
  root: { class: ['rounded-md border-l-4 bg-bg-subtle', borderClasses[props.variant]] },
  content: { class: 'flex flex-col gap-1 p-4 text-sm' },
  text: { class: 'flex flex-col gap-1' },
}))
</script>

<template>
  <Message :severity="severity[variant]" :pt="passThrough">
    <p class="font-semibold">{{ title ?? t(`base.alert.${variant}`) }}</p>
    <div class="text-text"><slot /></div>
  </Message>
</template>
