<script setup lang="ts">
import { ref } from 'vue'
import Popover from 'openvue/popover'

import BaseButton from './BaseButton.vue'
import BaseCheckbox from './BaseCheckbox.vue'

export interface PickerColumn {
  key: string
  label: string
  /** Always shown, such as the column that names each row. */
  locked?: boolean
}

defineProps<{
  columns: readonly PickerColumn[]
}>()

const hidden = defineModel<string[]>('hidden', { required: true })

const popover = ref<InstanceType<typeof Popover> | null>(null)

function setVisible(key: string, visible: boolean) {
  hidden.value = visible ? hidden.value.filter((hiddenKey) => hiddenKey !== key) : [...hidden.value, key]
}

const passThrough = {
  root: { class: 'z-50 mt-1 rounded-md border border-border bg-bg shadow-md' },
  content: { class: 'max-h-96 overflow-y-auto p-4' },
}
</script>

<template>
  <BaseButton label="Choose columns" variant="secondary" aria-haspopup="dialog" @click="(event: MouseEvent) => popover?.toggle(event)">
    <template #icon>
      <svg aria-hidden="true" viewBox="0 0 20 20" class="size-5" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round">
        <rect x="3" y="4" width="14" height="12" rx="1.5" />
        <path d="M7.75 4v12M12.25 4v12" />
      </svg>
    </template>
  </BaseButton>
  <Popover ref="popover" :pt="passThrough">
    <fieldset class="flex min-w-48 flex-col gap-3">
      <legend class="mb-3 text-sm font-semibold">Columns</legend>
      <BaseCheckbox
        v-for="column in columns"
        :key="column.key"
        :label="column.label"
        :model-value="column.locked || !hidden.includes(column.key)"
        :disabled="column.locked"
        @update:model-value="(visible: boolean) => setVisible(column.key, visible)"
      />
    </fieldset>
  </Popover>
</template>
