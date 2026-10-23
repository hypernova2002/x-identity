<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseActionMenu, { type ActionMenuItem } from '@/components/base/BaseActionMenu.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'
import { accountRoleOptions } from '@/utils/options'

const router = useRouter()
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

const items: ActionMenuItem[] = [
  { label: 'Profile and security', action: () => router.push({ name: 'security' }) },
  { label: 'Sign out', separatorBefore: true, action: signOut },
]
</script>

<template>
  <BaseActionMenu :items="items" label="Your profile">
    <template #trigger="{ toggle }">
      <button
        type="button"
        aria-haspopup="menu"
        :aria-label="`Your profile: ${me?.name ?? ''}`"
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
          Account {{ roleLabel?.toLowerCase() }} of <span class="font-medium text-text">{{ me?.account.name }}</span>
        </span>
      </p>
    </template>
  </BaseActionMenu>
</template>
