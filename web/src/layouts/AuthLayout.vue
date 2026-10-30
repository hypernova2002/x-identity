<script setup lang="ts">
import { RouterView } from 'vue-router'
</script>

<template>
  <div class="flex min-h-screen flex-col items-center justify-center gap-6 bg-bg-subtle px-4 py-12">
    <p class="text-xl font-semibold">{{ $t('shell.productName') }}</p>
    <main class="w-full max-w-md">
      <RouterView />
    </main>
  </div>
</template>
