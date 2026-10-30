<script setup lang="ts">
import { RouterView } from 'vue-router'
import { useI18n } from 'vue-i18n'

import BaseConfirmHost from '@/components/base/BaseConfirmHost.vue'

// Switching language remounts the page, so text that components build once, such as table
// columns, is built again in the new language.
const { locale } = useI18n()
</script>

<template>
  <RouterView :key="locale" />
  <BaseConfirmHost />
</template>
