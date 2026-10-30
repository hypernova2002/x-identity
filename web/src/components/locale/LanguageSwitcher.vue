<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

import BaseActionMenu, { type ActionMenuItem } from '@/components/base/BaseActionMenu.vue'
import LanguageFlag from '@/components/locale/LanguageFlag.vue'
import { LOCALE_NAMES, SUPPORTED_LOCALES, isSupportedLocale, type SupportedLocale } from '@/i18n'
import { useLocaleStore } from '@/stores/locale'

const { t } = useI18n()
const localeStore = useLocaleStore()

const current = computed<SupportedLocale>(() => (isSupportedLocale(localeStore.locale) ? localeStore.locale : 'en'))

const items = computed<ActionMenuItem[]>(() =>
  SUPPORTED_LOCALES.map((locale) => ({
    key: locale,
    label: LOCALE_NAMES[locale],
    current: locale === current.value,
    // The language switches straight away; saving it to a signed-in user can fail without
    // undoing that, and they can choose again.
    action: () => void localeStore.choose(locale).catch(() => undefined),
  })),
)
</script>

<template>
  <BaseActionMenu :items="items" :label="t('common.language.choose')">
    <template #trigger="{ toggle }">
      <button
        type="button"
        class="inline-flex h-10 items-center gap-2 rounded-md px-3 text-sm font-medium text-text hover:bg-bg-subtle focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary active:bg-border"
        aria-haspopup="menu"
        :aria-label="t('common.language.current', { name: LOCALE_NAMES[current] })"
        @click="toggle"
      >
        <LanguageFlag :locale="current" />
        <span class="hidden sm:inline" :lang="current">{{ LOCALE_NAMES[current] }}</span>
      </button>
    </template>
    <template #icon="{ key }">
      <LanguageFlag v-if="isSupportedLocale(key)" :locale="key" />
    </template>
  </BaseActionMenu>
</template>
