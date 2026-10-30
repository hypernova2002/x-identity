<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import { useI18n } from 'vue-i18n'

import BaseActionMenu, { type ActionMenuItem } from '@/components/base/BaseActionMenu.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'
import { accountRoleOptions } from '@/utils/options'

const router = useRouter()
const { t } = useI18n()
const session = useSessionStore()
const projectStore = useProjectStore()
const { me } = storeToRefs(session)

const initials = computed(() =>
  (me.value?.name ?? me.value?.email ?? '?')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]!.toUpperCase())
    .join(''),
)

const roleLabel = computed(() => accountRoleOptions.find((option) => option.value === me.value?.role)?.label ?? me.value?.role)

async function signOut() {
  const slug = session.account?.slug
  await session.signOut()
  projectStore.clear()
  await router.push(slug ? `/${slug}/sign-in` : '/sign-in')
}

const items = computed<ActionMenuItem[]>(() => [
  { label: t('shell.userMenu.profile'), action: () => router.push({ name: 'security' }) },
  { label: t('shell.userMenu.signOut'), separatorBefore: true, action: signOut },
])
</script>

<template>
  <BaseActionMenu :items="items" :label="t('shell.userMenu.label')">
    <template #trigger="{ toggle }">
      <button
        type="button"
        aria-haspopup="menu"
        :aria-label="t('shell.userMenu.trigger', { name: me?.name ?? '' })"
        class="inline-flex size-10 items-center justify-center rounded-full border border-border bg-primary-subtle text-sm font-semibold text-primary-active hover:border-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary active:bg-border"
        @click="toggle"
      >
        <span aria-hidden="true">{{ initials }}</span>
      </button>
    </template>
    <template #start>
      <p class="flex flex-col text-sm">
        <span class="truncate font-medium">{{ me?.name }}</span>
        <span class="truncate text-text-muted">{{ me?.email }}</span>
        <span class="mt-1 text-xs text-text-muted">
          <i18n-t keypath="shell.userMenu.role">
            <template #role>{{ roleLabel?.toLowerCase() }}</template>
            <template #account><span class="font-medium text-text">{{ me?.account.name }}</span></template>
          </i18n-t>
        </span>
      </p>
    </template>
  </BaseActionMenu>
</template>
