<script setup lang="ts">
import { computed } from 'vue'

export type StatusTone = 'success' | 'neutral' | 'warning' | 'danger' | 'info'

const props = defineProps<{
  tone: StatusTone
  label: string
}>()

const toneClasses: Record<StatusTone, string> = {
  success: 'border-success text-success',
  neutral: 'border-border text-text-muted',
  warning: 'border-warning text-warning',
  danger: 'border-danger text-danger',
  info: 'border-info text-info',
}

const symbols: Record<StatusTone, string> = { success: '●', neutral: '○', warning: '▲', danger: '■', info: '◆' }
const classes = computed(() => toneClasses[props.tone])
</script>

<template>
  <span class="inline-flex items-center gap-1 rounded-full border bg-bg px-2 py-0.5 text-xs font-medium whitespace-nowrap" :class="classes">
    <span aria-hidden="true">{{ symbols[tone] }}</span>
    {{ label }}
  </span>
</template>
