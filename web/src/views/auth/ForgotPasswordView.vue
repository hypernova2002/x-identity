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
  <BaseCard :title="$t('auth.forgotPassword.title')">
    <AccountLookupState :loading="accountLoading" :error="accountError" />

    <template v-if="account">
      <BaseAlert v-if="sent" variant="success" :title="$t('auth.forgotPassword.sentTitle')">
        {{ $t('auth.forgotPassword.sent', { email, account: account.name }) }}
      </BaseAlert>

      <form v-else class="flex flex-col gap-4" novalidate @submit.prevent="run()">
        <BaseAlert v-if="error" variant="danger">{{ error.message }}</BaseAlert>
        <BaseInput v-model="email" :label="$t('auth.fields.email')" type="email" autocomplete="email" required />
        <BaseButton type="submit" :label="$t('auth.forgotPassword.submit')" :loading="loading" />
      </form>

      <RouterLink
        :to="{ name: 'sign-in', params: { slug } }"
        class="text-sm font-medium text-primary underline hover:text-primary-hover"
      >
        {{ $t('auth.backToSignIn') }}
      </RouterLink>
    </template>
  </BaseCard>
</template>
