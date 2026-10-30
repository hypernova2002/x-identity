<script setup lang="ts">
import { RouterLink, type RouteLocationRaw } from 'vue-router'

export interface Breadcrumb {
  label: string
  to?: RouteLocationRaw
}

defineProps<{
  items: readonly Breadcrumb[]
}>()
</script>

<template>
  <nav :aria-label="$t('shell.breadcrumb')">
    <ol class="flex flex-wrap items-center gap-1 text-sm text-text-muted">
      <li v-for="(item, index) in items" :key="index" class="flex items-center gap-1">
        <span v-if="index > 0" aria-hidden="true">/</span>
        <RouterLink v-if="item.to && index < items.length - 1" :to="item.to" class="underline-offset-2 hover:text-text hover:underline">
          {{ item.label }}
        </RouterLink>
        <span v-else :aria-current="index === items.length - 1 ? 'page' : undefined">{{ item.label }}</span>
      </li>
    </ol>
  </nav>
</template>
