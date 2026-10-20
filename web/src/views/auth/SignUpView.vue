<script setup lang="ts">
import { ref, watch } from 'vue'
import { RouterLink, useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { authService, isChallenge } from '@/services/auth'
import { useSessionStore } from '@/stores/session'
import { slugify } from '@/utils/format'

const router = useRouter()
const session = useSessionStore()

const accountName = ref('')
const slug = ref('')
const slugEdited = ref(false)
const name = ref('')
const email = ref('')
const password = ref('')

watch(accountName, (value) => {
  if (!slugEdited.value) slug.value = slugify(value)
})

const { loading, error, run } = useAsyncAction(async () => {
  const { account } = await authService.signUp({
    account_name: accountName.value,
    slug: slug.value,
    name: name.value,
    email: email.value,
    password: password.value,
  })

  const result = await authService.signIn(account.uid, email.value, password.value).catch(() => null)
  if (result && !isChallenge(result)) {
    session.start(account, result)
    await router.push({ name: 'welcome' })
  } else {
    session.rememberAccount(account.slug)
    await router.push({ name: 'sign-in', params: { slug: account.slug } })
  }
})
</script>

<template>
  <BaseCard title="Create your account" description="Set up an account for your organisation. You'll be its owner.">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="run()">
      <BaseAlert v-if="error && error.details.length === 0" variant="danger">{{ error.message }}</BaseAlert>
      <BaseInput v-model="accountName" label="Organisation name" required :error="error?.fieldError('account_name')" />
      <BaseInput
        v-model="slug"
        label="Account alias"
        required
        hint="Used in your sign-in URL. Lowercase letters, numbers and hyphens."
        :error="error?.fieldError('slug')"
        @update:model-value="slugEdited = true"
      />
      <BaseInput v-model="name" label="Your name" autocomplete="name" required :error="error?.fieldError('name')" />
      <BaseInput v-model="email" label="Email" type="email" autocomplete="email" required :error="error?.fieldError('email')" />
      <BaseInput
        v-model="password"
        label="Password"
        type="password"
        autocomplete="new-password"
        required
        hint="At least 12 characters."
        :error="error?.fieldError('password')"
      />
      <BaseButton type="submit" label="Create account" :loading="loading" />
      <p class="text-sm text-text-muted">
        Already have an account?
        <RouterLink to="/sign-in" class="font-medium text-primary underline hover:text-primary-hover">Sign in</RouterLink>
      </p>
    </form>
  </BaseCard>
</template>
