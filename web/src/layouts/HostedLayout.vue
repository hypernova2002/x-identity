<script setup lang="ts">
import { RouterView } from 'vue-router'
</script>

<template>
  <div class="flex min-h-screen flex-col items-center justify-center gap-6 bg-bg-subtle px-4 py-12">
    <main class="w-full max-w-md">
      <RouterView />
    </main>
    <p class="text-xs text-text-muted">{{ $t('shell.securedBy') }}</p>
  </div>
</template>
