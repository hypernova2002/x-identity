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
  <p v-if="loading" class="text-sm text-text-muted" role="status">{{ $t('auth.accountLookup.loading') }}</p>
  <BaseAlert v-else-if="error?.code === 'not_found'" variant="danger" :title="$t('auth.accountLookup.notFound')">
    <i18n-t keypath="auth.accountLookup.notFoundDescription">
      <template #link>
        <RouterLink to="/sign-in" class="font-medium text-primary underline hover:text-primary-hover">{{ $t('auth.accountLookup.differentAccount') }}</RouterLink>
      </template>
    </i18n-t>
  </BaseAlert>
  <BaseAlert v-else-if="error" variant="danger">{{ error.message }}</BaseAlert>
</template>
