<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue'

import BaseButton from '@/components/base/BaseButton.vue'

const props = defineProps<{
  value: string
  /** What's copied, for assistive technology, e.g. "TXT record value". */
  label: string
}>()

const COPIED_FOR_MS = 2000

const copied = ref(false)
const failed = ref(false)
let reset: ReturnType<typeof setTimeout> | undefined

async function copy() {
  clearTimeout(reset)
  try {
    await navigator.clipboard.writeText(props.value)
    copied.value = true
    failed.value = false
  } catch {
    failed.value = true
  }
  reset = setTimeout(() => {
    copied.value = false
    failed.value = false
  }, COPIED_FOR_MS)
}

onBeforeUnmount(() => clearTimeout(reset))
</script>

<template>
  <BaseButton :label="copied ? 'Copied' : failed ? 'Copy failed' : 'Copy'" variant="ghost" size="sm" :aria-label="`Copy ${label}`" @click="copy" />
  <span class="sr-only" role="status">{{ copied ? `${label} copied` : failed ? `Couldn't copy ${label}; select it and copy it yourself.` : '' }}</span>
</template>
