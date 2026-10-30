<script setup lang="ts">
import BaseInput from './BaseInput.vue'
import BaseSearchSelect from './BaseSearchSelect.vue'
import BaseSelect from './BaseSelect.vue'
import type { DataTableFilter } from './types'

withDefaults(
  defineProps<{
    filter: DataTableFilter
    appendTo?: 'body' | 'self'
  }>(),
  { appendTo: 'body' },
)

const value = defineModel<string>({ required: true })
</script>

<template>
  <BaseSelect
    v-if="filter.type === 'select'"
    v-model="value"
    :label="filter.label"
    :options="[{ label: filter.anyLabel ?? $t('base.filters.any'), value: '' }, ...filter.options]"
    :append-to="appendTo"
  />
  <BaseSearchSelect
    v-else-if="filter.type === 'lookup'"
    v-model="value"
    :label="filter.label"
    :search="filter.search"
    :resolve-label="filter.resolveLabel"
    :see-all="filter.seeAll"
    :append-to="appendTo"
    :placeholder="$t('base.filters.any')"
  />
  <BaseInput v-else-if="filter.type === 'date'" v-model="value" :label="filter.label" type="date" />
  <BaseInput v-else v-model="value" :label="filter.label" type="search" />
</template>
