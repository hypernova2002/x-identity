<script setup lang="ts">
import { computed, ref } from 'vue'
import Popover from 'openvue/popover'

import BaseButton from './BaseButton.vue'

const props = defineProps<{
  /** How many of the filters inside are set. */
  activeCount: number
}>()

const popover = ref<InstanceType<typeof Popover> | null>(null)

const label = computed(() => (props.activeCount > 0 ? `More filters (${props.activeCount})` : 'More filters'))

const passThrough = {
  root: { class: 'z-50 mt-1 rounded-md border border-border bg-bg shadow-md' },
  content: { class: 'flex w-72 max-w-[calc(100vw-2rem)] flex-col gap-4 p-4' },
}
</script>

<template>
  <BaseButton :label="label" variant="secondary" aria-haspopup="dialog" @click="(event: MouseEvent) => popover?.toggle(event)" />
  <Popover ref="popover" :pt="passThrough" role="dialog" aria-label="More filters">
    <slot />
  </Popover>
</template>
