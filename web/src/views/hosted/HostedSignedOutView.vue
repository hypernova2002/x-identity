<script setup lang="ts">
import BaseCard from '@/components/base/BaseCard.vue'
</script>

<template>
  <BaseCard :title="$t('hosted.signedOut.title')">
    <p class="text-sm text-text-muted">{{ $t('hosted.signedOut.description') }}</p>
  </BaseCard>
</template>
