<script setup lang="ts">
import { RouterLink } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import type { ApiError } from '@/services/http'

defineProps<{
  loading: boolean
  error: ApiError | null
}>()
</script>

<template>
  <p v-if="loading" class="text-sm text-text-muted" role="status">Loading account…</p>
  <BaseAlert v-else-if="error?.code === 'not_found'" variant="danger" title="Account not found">
    There's no account with this alias. Check the link, or
    <RouterLink to="/sign-in" class="font-medium text-primary underline hover:text-primary-hover">enter a different account</RouterLink>.
  </BaseAlert>
  <BaseAlert v-else-if="error" variant="danger">{{ error.message }}</BaseAlert>
</template>
