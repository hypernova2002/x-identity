<script setup lang="ts">
import BaseAlert from '@/components/base/BaseAlert.vue'

defineProps<{
  codes: readonly string[]
}>()
</script>

<template>
  <div class="flex flex-col gap-4">
    <BaseAlert variant="warning" :title="$t('auth.recoveryCodes.title')">
      {{ $t('auth.recoveryCodes.description') }}
    </BaseAlert>
    <ul class="grid grid-cols-2 gap-2 rounded-md border border-border bg-bg-subtle p-4 font-mono text-sm" :aria-label="$t('auth.recoveryCodes.label')">
      <li v-for="code in codes" :key="code">{{ code }}</li>
    </ul>
  </div>
</template>
