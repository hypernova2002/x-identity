<script setup lang="ts">
import { RouterLink } from 'vue-router'
</script>

<template>
  <main class="mx-auto flex min-h-screen max-w-3xl flex-col justify-center gap-4 p-6">
    <h1 class="text-2xl font-semibold">{{ $t('shell.notFound.title') }}</h1>
    <p class="text-text-muted">{{ $t('shell.notFound.description') }}</p>
    <RouterLink
      to="/"
      class="w-fit rounded-sm font-medium text-primary underline hover:text-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
    >
      {{ $t('shell.notFound.home') }}
    </RouterLink>
  </main>
</template>
