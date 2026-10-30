<script setup lang="ts">
import { computed } from 'vue'

import { decodeJwt } from '@/utils/jwt'
import { formatDateTime } from '@/utils/format'

const props = defineProps<{
  label: string
  token: string
}>()

const decoded = computed(() => decodeJwt(props.token))

const times = computed(() => {
  const payload = decoded.value?.payload
  if (!payload) return []

  return (['iat', 'auth_time', 'exp'] as const)
    .filter((claim) => typeof payload[claim] === 'number')
    .map((claim) => ({ claim, value: formatDateTime(new Date((payload[claim] as number) * 1000).toISOString()) }))
})
</script>

<template>
  <section class="flex flex-col gap-2" :aria-label="label">
    <h3 class="text-sm font-semibold">{{ label }}</h3>

    <details class="rounded-md border border-border">
      <summary class="cursor-pointer px-3 py-2 text-sm text-text-muted">{{ $t('project.decodedToken.encodedToken') }}</summary>
      <code class="block border-t border-border bg-bg-subtle px-3 py-2 font-mono text-xs break-all">{{ token }}</code>
    </details>

    <template v-if="decoded">
      <dl v-if="times.length > 0" class="flex flex-wrap gap-x-6 gap-y-1 text-xs">
        <div v-for="time in times" :key="time.claim" class="flex gap-1">
          <dt class="font-mono text-text-muted">{{ time.claim }}</dt>
          <dd>{{ time.value }}</dd>
        </div>
      </dl>
      <div class="grid gap-2 lg:grid-cols-2">
        <pre class="overflow-x-auto rounded-md bg-bg-subtle p-3 font-mono text-xs" :aria-label="$t('project.decodedToken.header')">{{ JSON.stringify(decoded.header, null, 2) }}</pre>
        <pre class="overflow-x-auto rounded-md bg-bg-subtle p-3 font-mono text-xs" :aria-label="$t('project.decodedToken.claims')">{{ JSON.stringify(decoded.payload, null, 2) }}</pre>
      </div>
    </template>
    <p v-else class="text-xs text-text-muted">{{ $t('project.decodedToken.opaqueTokenItHasNo') }}</p>
  </section>
</template>
