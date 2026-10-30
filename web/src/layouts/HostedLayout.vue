<script setup lang="ts">
import { RouterView } from 'vue-router'

import LanguageSwitcher from '@/components/locale/LanguageSwitcher.vue'
</script>

<template>
  <div class="relative flex min-h-screen flex-col items-center justify-center gap-6 bg-bg-subtle px-4 py-12">
    <div class="absolute top-4 right-4">
      <LanguageSwitcher />
    </div>
    <main class="w-full max-w-md">
      <RouterView />
    </main>
    <p class="text-xs text-text-muted">{{ $t('shell.securedBy') }}</p>
  </div>
</template>
