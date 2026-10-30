<script setup lang="ts">
import { ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { authService } from '@/services/auth'
import { useSessionStore } from '@/stores/session'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()

const slug = ref(session.lastAccountSlug() ?? '')

const { loading, error, run } = useAsyncAction(async () => {
  const account = await authService.lookupAccount(slug.value.trim().toLowerCase())
  session.rememberAccount(account.slug)
  await router.push({ name: 'sign-in', params: { slug: account.slug }, query: route.query })
})
</script>

<template>
  <BaseCard :title="$t('auth.picker.title')" :description="$t('auth.picker.description')">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="run()">
      <BaseInput
        v-model="slug"
        :label="$t('auth.fields.accountAlias')"
        required
        autocomplete="organization"
        :error="error ? (error.code === 'not_found' ? $t('auth.picker.noAccount') : error.message) : undefined"
      />
      <BaseButton type="submit" :label="$t('common.actions.continue')" :loading="loading" />
      <p class="text-sm text-text-muted">
        {{ $t('auth.picker.newHere') }}
        <RouterLink to="/sign-up" class="font-medium text-primary underline hover:text-primary-hover">{{ $t('auth.picker.createAccount') }}</RouterLink>
      </p>
    </form>
  </BaseCard>
</template>
