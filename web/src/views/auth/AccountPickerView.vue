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
  <BaseCard title="Sign in" description="Enter your account alias to continue.">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="run()">
      <BaseInput
        v-model="slug"
        label="Account alias"
        required
        autocomplete="organization"
        :error="error ? (error.code === 'not_found' ? 'There is no account with this alias.' : error.message) : undefined"
      />
      <BaseButton type="submit" label="Continue" :loading="loading" />
      <p class="text-sm text-text-muted">
        New to x-identity?
        <RouterLink to="/sign-up" class="font-medium text-primary underline hover:text-primary-hover">Create an account</RouterLink>
      </p>
    </form>
  </BaseCard>
</template>
