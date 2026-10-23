<script setup lang="ts">
import Drawer from 'openvue/drawer'

defineProps<{
  title: string
}>()

const visible = defineModel<boolean>('visible', { required: true })

const passThrough = {
  mask: { class: 'fixed inset-0 z-50 flex bg-text/40' },
  root: { class: 'flex h-full w-72 max-w-[85vw] flex-col bg-bg-subtle shadow-lg' },
  header: { class: 'flex items-center justify-between gap-4 border-b border-border px-4 py-3' },
  title: { class: 'text-base font-semibold' },
  pcCloseButton: {
    root: {
      class: [
        'inline-flex size-10 items-center justify-center rounded-md text-text-muted',
        'hover:bg-border hover:text-text active:bg-border',
        'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary',
      ],
    },
  },
  content: { class: 'flex flex-1 flex-col overflow-y-auto' },
}
</script>

<template>
  <Drawer v-model:visible="visible" :header="title" position="left" modal block-scroll :pt="passThrough">
    <slot />
  </Drawer>
</template>
