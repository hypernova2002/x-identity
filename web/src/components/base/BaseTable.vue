<script setup lang="ts" generic="Row">
// A plain semantic table. OpenVue's DataTable brings client-side sorting, selection and its own
// pagination, none of which these server-paginated lists use, and needs dozens of pass-through
// sections in unstyled mode.
import type { TableColumn } from './types'

defineProps<{
  caption: string
  columns: readonly TableColumn[]
  rows: readonly Row[]
  rowKey: (row: Row) => string
  loading?: boolean
  emptyMessage: string
}>()

defineSlots<{
  [key: `cell-${string}`]: (props: { row: Row }) => unknown
  empty?: () => unknown
}>()
</script>

<template>
  <div class="overflow-x-auto rounded-lg border border-border">
    <table class="w-full border-collapse text-left text-sm" :aria-busy="loading || undefined">
      <caption class="sr-only">{{ caption }}</caption>
      <thead class="bg-bg-subtle">
        <tr>
          <th v-for="column in columns" :key="column.key" scope="col" class="px-4 py-3 font-semibold">
            <span :class="{ 'sr-only': column.srOnly }">{{ column.label }}</span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="loading && rows.length === 0">
          <td :colspan="columns.length" class="px-4 py-8 text-center text-text-muted">Loading…</td>
        </tr>
        <tr v-else-if="rows.length === 0">
          <td :colspan="columns.length" class="px-4 py-8 text-center text-text-muted">
            <slot name="empty">{{ emptyMessage }}</slot>
          </td>
        </tr>
        <template v-else>
          <tr v-for="row in rows" :key="rowKey(row)" class="border-t border-border hover:bg-bg-subtle">
            <td v-for="column in columns" :key="column.key" class="px-4 py-3 align-middle">
              <slot :name="`cell-${column.key}`" :row="row">{{ (row as Record<string, unknown>)[column.key] }}</slot>
            </td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>
