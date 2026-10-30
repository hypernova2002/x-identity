<script setup lang="ts">
import { computed, ref } from 'vue'
import Menu from 'openvue/menu'
import { useI18n } from 'vue-i18n'

import BaseButton from './BaseButton.vue'

export interface ActionMenuItem {
  label: string
  action: () => void
  /** Security-sensitive or destructive actions are set apart and coloured as dangerous. */
  danger?: boolean
  disabled?: boolean
  /** Marks the selected entry in a menu used for switching, e.g. the open project. */
  current?: boolean
  separatorBefore?: boolean
  /** Passed to the `icon` slot, to draw something before the label, such as a flag. */
  key?: string
}

const props = defineProps<{
  items: readonly ActionMenuItem[]
  /** Names the menu for assistive technology, e.g. "More actions for casey@shop.test". */
  label: string
  /** Defaults to "More". */
  buttonLabel?: string
}>()

const { t } = useI18n()

defineSlots<{
  /** A custom trigger; call `toggle` with the click event to open the menu below it. */
  trigger?(scope: { toggle: (event: Event) => void }): unknown
  /** Non-interactive content above the items, such as who is signed in. */
  start?(): unknown
  /** Drawn before an item's label; decorative, since the label names the item. */
  icon?(scope: { key: string | undefined }): unknown
}>()

const menu = ref<InstanceType<typeof Menu> | null>(null)

const showsCurrent = computed(() => props.items.some((item) => item.current))

const model = computed(() => {
  const regular = props.items.filter((item) => !item.danger)
  const dangerous = props.items.filter((item) => item.danger)
  const entry = (item: ActionMenuItem) => ({
    key: item.key,
    label: item.label,
    disabled: item.disabled,
    current: item.current ?? false,
    command: () => item.action(),
    class: item.danger ? 'text-danger' : item.current ? 'font-semibold text-primary-active' : 'text-text',
  })
  const withSeparators = (items: ActionMenuItem[]) =>
    items.flatMap((item, index) => [...(item.separatorBefore && index > 0 ? [{ separator: true }] : []), entry(item)])
  return [...withSeparators(regular), ...(regular.length > 0 && dangerous.length > 0 ? [{ separator: true }] : []), ...dangerous.map(entry)]
})

function toggle(event: Event) {
  menu.value?.toggle(event)
}

const passThrough = {
  root: { class: 'z-50 max-w-[min(20rem,calc(100vw-2rem))] min-w-48 rounded-md border border-border bg-bg py-1 shadow-md' },
  list: { class: 'flex max-h-96 flex-col overflow-y-auto outline-none' },
  item: { class: 'focus-within:bg-bg-subtle data-[p-focused=true]:bg-bg-subtle data-[p-disabled=true]:opacity-60' },
  itemContent: { class: 'hover:bg-bg-subtle' },
  separator: { class: 'my-1 border-t border-border' },
  start: { class: 'border-b border-border px-3 py-2' },
}
</script>

<template>
  <slot name="trigger" :toggle="toggle">
    <BaseButton :label="buttonLabel ?? t('base.actionMenu.more')" variant="ghost" size="sm" aria-haspopup="menu" :aria-label="label" @click="toggle" />
  </slot>
  <Menu ref="menu" :model="model" popup :aria-label="label" :pt="passThrough">
    <template v-if="$slots.start" #start>
      <slot name="start" />
    </template>
    <template #item="{ item, props: itemProps }">
      <a v-bind="itemProps.action" class="flex cursor-pointer items-center gap-2 px-3 py-2 text-sm no-underline" :class="item.class">
        <span v-if="showsCurrent" aria-hidden="true" class="w-4 shrink-0">{{ item.current ? '✓' : '' }}</span>
        <span v-if="$slots.icon" aria-hidden="true" class="flex shrink-0"><slot name="icon" :key="item.key" /></span>
        <span class="truncate">{{ item.label }}</span>
        <span v-if="item.current" class="sr-only">{{ t('base.actionMenu.current') }}</span>
      </a>
    </template>
  </Menu>
</template>
