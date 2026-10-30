<script setup lang="ts">
// The one place confirmation requests from useConfirmation() appear. Mount it once, in App.vue.
import ConfirmDialog from 'openvue/confirmdialog'

import BaseButton from './BaseButton.vue'

const passThrough = {
  mask: { class: 'fixed inset-0 z-50 flex items-center justify-center bg-text/40 p-4' },
  root: { class: 'flex max-h-full w-full max-w-md flex-col rounded-lg bg-bg shadow-lg' },
}
</script>

<template>
  <ConfirmDialog :pt="passThrough" :draggable="false">
    <template #container="{ message, acceptCallback, rejectCallback }">
      <div class="flex items-center justify-between gap-4 border-b border-border p-4">
        <h2 class="text-lg font-semibold">{{ message.header }}</h2>
      </div>
      <p class="p-4 text-sm">{{ message.message }}</p>
      <div class="flex flex-wrap justify-end gap-2 border-t border-border p-4">
        <BaseButton :label="message.rejectLabel ?? $t('base.confirm.cancel')" variant="secondary" @click="rejectCallback" />
        <BaseButton :label="message.acceptLabel ?? $t('base.confirm.confirm')" :variant="message.acceptProps?.danger ? 'danger' : 'primary'" @click="acceptCallback" />
      </div>
    </template>
  </ConfirmDialog>
</template>
