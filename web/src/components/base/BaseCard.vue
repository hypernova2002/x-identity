<script setup lang="ts">
import Card from 'openvue/card'

defineProps<{
  title?: string
  description?: string
}>()

const passThrough = {
  root: { class: 'rounded-lg border border-border bg-bg shadow-sm' },
  body: { class: 'flex flex-col gap-4 p-6' },
  caption: { class: 'flex flex-col gap-1' },
  title: { class: 'text-lg font-semibold' },
  subtitle: { class: 'text-sm text-text-muted' },
  content: { class: 'flex flex-col gap-4' },
  footer: { class: 'flex flex-wrap justify-end gap-2' },
}
</script>

<template>
  <Card :pt="passThrough">
    <template v-if="title" #title>
      <h2>{{ title }}</h2>
    </template>
    <template v-if="description" #subtitle>{{ description }}</template>
    <template #content>
      <slot />
    </template>
    <template v-if="$slots.footer" #footer>
      <slot name="footer" />
    </template>
  </Card>
</template>
