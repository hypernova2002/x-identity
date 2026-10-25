<script setup lang="ts">
import { useRoute } from 'vue-router'

import PageHeader from './PageHeader.vue'

// For pages whose route sets `ownHeader` so they can add actions, such as "Create", to the title
// and description the project layout would otherwise show.
const route = useRoute()
</script>

<template>
  <PageHeader :title="route.meta.title ?? ''" :description="route.meta.description">
    <template v-if="$slots.actions" #actions>
      <slot name="actions" />
    </template>
  </PageHeader>
</template>
