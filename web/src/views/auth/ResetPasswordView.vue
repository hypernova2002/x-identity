<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink, useRoute } from 'vue-router'

import AccountLookupState from '@/components/auth/AccountLookupState.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import { useAccountFromRoute } from '@/composables/useAccountFromRoute'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { authService } from '@/services/auth'

const route = useRoute()
const { account, slug, loading: accountLoading, error: accountError } = useAccountFromRoute()

const token = computed(() => String(route.query.token ?? ''))
const password = ref('')
const done = ref(false)

const { loading, error, run } = useAsyncAction(async () => {
  if (!account.value) return
  await authService.resetPassword(account.value.uid, token.value, password.value)
  done.value = true
})
</script>

<template>
  <BaseCard :title="$t('auth.resetPassword.title')">
    <AccountLookupState :loading="accountLoading" :error="accountError" />

    <template v-if="account">
      <BaseAlert v-if="done" variant="success" :title="$t('auth.resetPassword.doneTitle')">
        {{ $t('auth.resetPassword.done') }}
      </BaseAlert>
      <BaseAlert v-else-if="error?.code === 'invalid_token'" variant="danger" :title="$t('auth.linkInvalid')">
        {{ $t('auth.linkExpired') }}
        <RouterLink :to="{ name: 'forgot-password', params: { slug } }" class="font-medium text-primary underline">
          {{ $t('auth.resetPassword.requestNewLink') }}
        </RouterLink>.
      </BaseAlert>

      <form v-if="!done" class="flex flex-col gap-4" novalidate @submit.prevent="run()">
        <BaseInput
          v-model="password"
          :label="$t('auth.fields.newPassword')"
          type="password"
          autocomplete="new-password"
          required
          :error="error?.fieldError('password')"
        />
        <BaseButton type="submit" :label="$t('auth.resetPassword.submit')" :loading="loading" />
      </form>

      <RouterLink
        :to="{ name: 'sign-in', params: { slug } }"
        class="text-sm font-medium text-primary underline hover:text-primary-hover"
      >
        {{ $t('auth.goToSignIn') }}
      </RouterLink>
    </template>
  </BaseCard>
</template>
