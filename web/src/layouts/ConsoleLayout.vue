<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, RouterView, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseButton from '@/components/base/BaseButton.vue'
import { useSessionStore } from '@/stores/session'

const router = useRouter()
const session = useSessionStore()
const { me, isAccountAdmin } = storeToRefs(session)

const navigation = computed(() => [
  { to: { name: 'projects' }, label: 'Projects', visible: true },
  { to: { name: 'users' }, label: 'Users', visible: isAccountAdmin.value },
  { to: { name: 'auth-settings' }, label: 'Authentication', visible: isAccountAdmin.value },
  { to: { name: 'audit-log' }, label: 'Audit log', visible: isAccountAdmin.value },
  { to: { name: 'security' }, label: 'My security', visible: true },
])

const visibleNavigation = computed(() => navigation.value.filter((item) => item.visible))

async function signOut() {
  const slug = session.account?.slug
  await session.signOut()
  await router.push(slug ? `/${slug}/sign-in` : '/sign-in')
}
</script>

<template>
  <div class="flex min-h-screen flex-col md:flex-row">
    <aside class="flex flex-col gap-6 border-b border-border bg-bg-subtle p-4 md:w-64 md:border-r md:border-b-0">
      <div class="flex flex-col gap-1">
        <p class="text-lg font-semibold">x-identity</p>
        <p class="text-sm text-text-muted">{{ me?.account.name }}</p>
      </div>
      <nav aria-label="Console">
        <ul class="flex flex-wrap gap-1 md:flex-col">
          <li v-for="item in visibleNavigation" :key="item.label">
            <RouterLink
              :to="item.to"
              class="block rounded-md border-l-4 border-transparent px-3 py-2 text-sm text-text hover:bg-border focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary aria-[current=page]:border-primary aria-[current=page]:bg-primary-subtle aria-[current=page]:font-semibold aria-[current=page]:text-primary-active"
            >
              {{ item.label }}
            </RouterLink>
          </li>
        </ul>
      </nav>
      <div class="mt-auto flex flex-col gap-2">
        <p class="text-sm">
          <span class="font-medium">{{ me?.name }}</span>
          <span class="block text-text-muted">{{ me?.email }} · {{ me?.role }}</span>
        </p>
        <BaseButton label="Sign out" variant="secondary" size="sm" @click="signOut" />
      </div>
    </aside>
    <main class="flex-1 p-6">
      <div class="mx-auto flex max-w-5xl flex-col gap-8">
        <RouterView />
      </div>
    </main>
  </div>
</template>
