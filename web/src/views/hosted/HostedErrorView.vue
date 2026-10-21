<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import BaseCard from '@/components/base/BaseCard.vue'

const route = useRoute()

const description = computed(() => String(route.query.error_description ?? "The sign-in couldn't be completed."))
const code = computed(() => (route.query.error ? String(route.query.error) : null))
</script>

<template>
  <BaseCard title="We couldn't sign you in">
    <p class="text-sm">{{ description }}</p>
    <p class="text-sm text-text-muted">Go back to the app you came from and try again.</p>
    <p v-if="code" class="text-xs text-text-muted">Error code: <code class="font-mono">{{ code }}</code></p>
  </BaseCard>
</template>
