<script setup lang="ts">
import Dialog from 'openvue/dialog'

defineProps<{
  title: string
}>()

const visible = defineModel<boolean>('visible', { required: true })

const passThrough = {
  mask: { class: 'fixed inset-0 z-50 flex items-center justify-center bg-text/40 p-4' },
  root: { class: 'flex max-h-full w-full max-w-lg flex-col rounded-lg bg-bg shadow-lg' },
  header: { class: 'flex items-center justify-between gap-4 border-b border-border p-4' },
  title: { class: 'text-lg font-semibold' },
  pcCloseButton: {
    root: {
      class: [
        'inline-flex size-8 items-center justify-center rounded-md text-text-muted',
        'hover:bg-bg-subtle hover:text-text active:bg-border',
        'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary',
      ],
    },
  },
  content: { class: 'flex flex-col gap-4 overflow-y-auto p-4' },
  footer: { class: 'flex flex-wrap justify-end gap-2 border-t border-border p-4' },
}
</script>

<template>
  <Dialog v-model:visible="visible" :header="title" modal dismissable-mask :draggable="false" :pt="passThrough">
    <slot />
    <template v-if="$slots.footer" #footer>
      <slot name="footer" />
    </template>
  </Dialog>
</template>
