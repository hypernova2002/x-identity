<script setup lang="ts">
import { ref, watch } from 'vue'
import { RouterLink, useRoute } from 'vue-router'

import AccountLookupState from '@/components/auth/AccountLookupState.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import { useAccountFromRoute } from '@/composables/useAccountFromRoute'
import { useAsyncAction } from '@/composables/useAsyncAction'

const props = defineProps<{
  title: string
  successTitle: string
  successMessage: string
  confirm: (accountUid: string, token: string) => Promise<unknown>
}>()

const route = useRoute()
const { account, slug, loading: accountLoading, error: accountError } = useAccountFromRoute()

const done = ref(false)

const { error, run } = useAsyncAction(async (accountUid: string) => {
  await props.confirm(accountUid, String(route.query.token ?? ''))
  done.value = true
})

watch(
  account,
  (value) => {
    if (value) run(value.uid)
  },
  { once: true },
)
</script>

<template>
  <BaseCard :title="title">
    <AccountLookupState :loading="accountLoading" :error="accountError" />

    <template v-if="account">
      <BaseAlert v-if="done" variant="success" :title="successTitle">{{ successMessage }}</BaseAlert>
      <BaseAlert v-else-if="error" variant="danger" title="This link doesn't work">
        {{ error.code === 'invalid_token' ? 'It may have expired or already been used.' : error.message }}
      </BaseAlert>
      <p v-else class="text-sm text-text-muted" role="status">Confirming…</p>

      <RouterLink
        :to="{ name: 'sign-in', params: { slug } }"
        class="text-sm font-medium text-primary underline hover:text-primary-hover"
      >
        Go to sign in
      </RouterLink>
    </template>
  </BaseCard>
</template>
