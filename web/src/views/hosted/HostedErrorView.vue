<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import BaseCard from '@/components/base/BaseCard.vue'
import { errorMessage } from '@/services/http'

const route = useRoute()

const code = computed(() => (route.query.error ? String(route.query.error) : null))
</script>

<template>
  <BaseCard :title="$t('hosted.error.title')">
    <p class="text-sm">{{ code ? errorMessage(code) : $t('hosted.error.generic') }}</p>
    <p class="text-sm text-text-muted">{{ $t('hosted.error.goBack') }}</p>
    <i18n-t v-if="code" keypath="hosted.error.code" tag="p" class="text-xs text-text-muted">
      <template #code><code class="font-mono">{{ code }}</code></template>
    </i18n-t>
  </BaseCard>
</template>
