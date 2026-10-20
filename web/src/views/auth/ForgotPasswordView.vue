<script setup lang="ts">
import { ref } from 'vue'
import { RouterLink } from 'vue-router'

import AccountLookupState from '@/components/auth/AccountLookupState.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import { useAccountFromRoute } from '@/composables/useAccountFromRoute'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { authService } from '@/services/auth'

const { account, slug, loading: accountLoading, error: accountError } = useAccountFromRoute()

const email = ref('')
const sent = ref(false)

const { loading, error, run } = useAsyncAction(async () => {
  if (!account.value) return
  await authService.forgotPassword(account.value.uid, email.value)
  sent.value = true
})
</script>

<template>
  <BaseCard title="Reset your password">
    <AccountLookupState :loading="accountLoading" :error="accountError" />

    <template v-if="account">
      <BaseAlert v-if="sent" variant="success" title="Check your email">
        If {{ email }} belongs to a user in {{ account.name }}, we've sent a link to reset the password. It expires in 1 hour.
      </BaseAlert>

      <form v-else class="flex flex-col gap-4" novalidate @submit.prevent="run()">
        <BaseAlert v-if="error" variant="danger">{{ error.message }}</BaseAlert>
        <BaseInput v-model="email" label="Email" type="email" autocomplete="email" required />
        <BaseButton type="submit" label="Send reset link" :loading="loading" />
      </form>

      <RouterLink
        :to="{ name: 'sign-in', params: { slug } }"
        class="text-sm font-medium text-primary underline hover:text-primary-hover"
      >
        Back to sign in
      </RouterLink>
    </template>
  </BaseCard>
</template>
