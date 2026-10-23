<script setup lang="ts">
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import type { ApiError } from '@/services/http'

withDefaults(
  defineProps<{
    title: string
    confirmLabel: string
    danger?: boolean
    loading?: boolean
    error?: ApiError | null
  }>(),
  { danger: false, loading: false, error: null },
)

const emit = defineEmits<{
  confirm: []
}>()

const visible = defineModel<boolean>('visible', { required: true })
</script>

<template>
  <BaseDialog v-model:visible="visible" :title="title">
    <div class="flex flex-col gap-3 text-sm">
      <slot />
    </div>
    <BaseAlert v-if="error" variant="danger">{{ error.message }}</BaseAlert>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="visible = false" />
      <BaseButton :label="confirmLabel" :variant="danger ? 'danger' : 'primary'" :loading="loading" @click="emit('confirm')" />
    </template>
  </BaseDialog>
</template>
