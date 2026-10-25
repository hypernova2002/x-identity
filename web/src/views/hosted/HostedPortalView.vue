<script setup lang="ts">
import { watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import AccountLookupState from '@/components/auth/AccountLookupState.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import PasskeysCard from '@/components/security/PasskeysCard.vue'
import DeviceSessionTable from '@/components/sessions/DeviceSessionTable.vue'
import { useHostedProject } from '@/composables/useHostedProject'
import { usePortal } from '@/composables/usePortal'
import { onCustomDomain } from '@/utils/customDomain'

const route = useRoute()
const router = useRouter()
const { account, loading: accountLoading, error: accountError } = useHostedProject()
// Names the portal's session storage; a custom domain's storage is its own already.
const portal = usePortal(onCustomDomain() ? window.location.host : String(route.params.projectUid))
const { apps, email, accessToken } = portal

const text = (key: string) => (typeof route.query[key] === 'string' ? (route.query[key] as string) : undefined)

watch(
  account,
  async (loaded) => {
    if (!loaded) return
    const returned = text('code') || text('error')
      ? { code: text('code'), state: text('state'), error: text('error'), errorDescription: text('error_description') }
      : null
    if (returned) await router.replace({ query: {} })
    portal.open.run(loaded.uid, returned)
  },
  { immediate: true },
)
</script>

<template>
  <BaseCard title="Your apps" :description="email ? `Signed in as ${email}` : undefined">
    <AccountLookupState :loading="accountLoading" :error="accountError" />
    <BaseAlert v-if="portal.open.error.value" variant="danger">
      {{ portal.open.error.value.message }}
    </BaseAlert>
    <p v-else-if="portal.open.loading.value" class="text-sm text-text-muted" role="status">Loading your apps…</p>

    <template v-else-if="email !== null || apps.length > 0">
      <p v-if="apps.length === 0" class="text-sm text-text-muted">You don't have access to any apps yet. Ask an administrator to give you access.</p>
      <ul v-else class="grid gap-2 sm:grid-cols-2">
        <li v-for="app in apps" :key="app.uid">
          <BaseButton :label="app.name" variant="secondary" class="w-full" @click="portal.launch(app)" />
        </li>
      </ul>
    </template>

    <template #footer>
      <BaseButton label="Log out" variant="ghost" @click="portal.logOut()" />
    </template>
  </BaseCard>

  <PasskeysCard
    v-if="accessToken && !portal.open.loading.value"
    :available="portal.config.value?.passkeys_available ?? false"
    v-bind="portal.passkeys"
    @reauthenticate="portal.signInAgain()"
  />

  <BaseCard v-if="accessToken && !portal.open.loading.value" title="Your devices" description="Where you're signed in. Sign out any device you don't recognise.">
    <DeviceSessionTable :fetch-page="portal.fetchSessions" :sign-out="portal.signOutSession" :sign-out-others="portal.signOutOtherSessions" />
  </BaseCard>
</template>
