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
import type { User } from '@/types/api'

const route = useRoute()
const { account, slug, loading: accountLoading, error: accountError } = useAccountFromRoute()

const token = computed(() => String(route.query.token ?? ''))
const name = ref('')
const password = ref('')
const createdUser = ref<User | null>(null)

const { loading, error, run } = useAsyncAction(async () => {
  if (!account.value) return
  createdUser.value = await authService.acceptInvitation(account.value.uid, token.value, name.value, password.value)
})
</script>

<template>
  <BaseCard :title="account ? $t('auth.acceptInvitation.join', { account: account.name }) : $t('auth.acceptInvitation.title')">
    <AccountLookupState :loading="accountLoading" :error="accountError" />

    <template v-if="account">
      <template v-if="createdUser">
        <BaseAlert variant="success" :title="$t('auth.acceptInvitation.doneTitle')">
          {{ $t('auth.acceptInvitation.done', { email: createdUser.email }) }}
        </BaseAlert>
        <RouterLink
          :to="{ name: 'sign-in', params: { slug } }"
          class="text-sm font-medium text-primary underline hover:text-primary-hover"
        >
          {{ $t('auth.goToSignIn') }}
        </RouterLink>
      </template>

      <form v-else class="flex flex-col gap-4" novalidate @submit.prevent="run()">
        <BaseAlert v-if="error?.code === 'invalid_token'" variant="danger" :title="$t('auth.acceptInvitation.invalidTitle')">
          {{ $t('auth.acceptInvitation.invalid') }}
        </BaseAlert>
        <BaseAlert v-else-if="error && error.details.length === 0" variant="danger">{{ error.message }}</BaseAlert>
        <BaseInput v-model="name" :label="$t('auth.fields.yourName')" autocomplete="name" required :error="error?.fieldError('name')" />
        <BaseInput
          v-model="password"
          :label="$t('auth.fields.password')"
          type="password"
          autocomplete="new-password"
          required
          :error="error?.fieldError('password')"
        />
        <BaseButton type="submit" :label="$t('auth.acceptInvitation.submit')" :loading="loading" />
      </form>
    </template>
  </BaseCard>
</template>
