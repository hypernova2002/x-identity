<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'

import AccountLookupState from '@/components/auth/AccountLookupState.vue'
import RecoveryCodesList from '@/components/auth/RecoveryCodesList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import HostedChallengeForm from '@/components/hosted/HostedChallengeForm.vue'
import { useAccountFromRoute } from '@/composables/useAccountFromRoute'
import { useHostedLogin } from '@/composables/useHostedLogin'
import type { SignInChallengeName } from '@/types/api'

const CHALLENGES: SignInChallengeName[] = ['otp', 'new_password', 'mfa_setup']

const route = useRoute()
const { account, loading: accountLoading, error: accountError } = useAccountFromRoute()
const login = useHostedLogin()
const { details, step, email, challenge, enrollment, recoveryCodes, notice, passwordStep } = login

const password = ref('')
const name = ref('')
const code = ref('')
const newPassword = ref('')

const query = (key: string) => (typeof route.query[key] === 'string' ? (route.query[key] as string) : '')
const providerError = ref(query('error_description'))

const title = computed(() => {
  const project = details.value?.project_name ?? 'your account'
  switch (step.value) {
    case 'challenge':
      return challenge.value?.challenge === 'mfa_setup' ? 'Set up multi-factor authentication' : challenge.value?.challenge === 'new_password' ? 'Choose a new password' : 'Enter your verification code'
    case 'recovery-codes':
      return 'Multi-factor authentication is on'
    case 'sign-up':
      return `Create your ${project} account`
    case 'confirm-sign-up':
      return 'Confirm your email'
    case 'forgot-password':
    case 'reset-password':
      return 'Reset your password'
    default:
      return `Sign in to ${project}`
  }
})

const interactionExpired = computed(() => login.load.error.value?.code === 'invalid_interaction')

function show(next: typeof step.value) {
  code.value = ''
  newPassword.value = ''
  providerError.value = ''
  for (const action of [login.signIn, login.answer, login.signUp, login.confirmSignUp, login.forgotPassword, login.resetPassword]) {
    action.error.value = null
  }
  login.go(next)
}

watch(
  account,
  (loaded) => {
    if (!loaded) return
    const resumeChallenge = query('challenge') as SignInChallengeName
    const resume = CHALLENGES.includes(resumeChallenge) && query('session') ? { challenge: resumeChallenge, session: query('session') } : undefined
    login.load.run({ accountUid: loaded.uid, projectUid: String(route.params.projectUid), interaction: query('interaction') }, resume)
  },
  { immediate: true },
)
</script>

<template>
  <BaseCard :title="title" :description="step === 'sign-in' && details ? `to continue to ${details.app_name}` : undefined">
    <AccountLookupState :loading="accountLoading" :error="accountError" />

    <BaseAlert v-if="interactionExpired" variant="warning" title="This sign-in has expired">
      Go back to the app you came from and sign in again.
    </BaseAlert>
    <BaseAlert v-else-if="login.load.error.value" variant="danger">{{ login.load.error.value.message }}</BaseAlert>
    <p v-else-if="login.load.loading.value" class="text-sm text-text-muted" role="status">Loading…</p>

    <template v-else-if="details">
      <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>

      <template v-if="step === 'sign-in'">
        <BaseAlert v-if="providerError" variant="danger">{{ providerError }}</BaseAlert>
        <form class="flex flex-col gap-4" novalidate @submit.prevent="passwordStep ? login.signIn.run(password) : login.discover.run()">
          <BaseAlert v-if="login.signIn.error.value && login.signIn.error.value.details.length === 0" variant="danger">
            {{ login.signIn.error.value.message }}
          </BaseAlert>
          <BaseAlert v-if="login.discover.error.value" variant="danger">{{ login.discover.error.value.message }}</BaseAlert>
          <BaseInput
            v-model="email"
            label="Email"
            type="email"
            autocomplete="username"
            required
            :error="login.signIn.error.value?.fieldError('email') ?? login.discover.error.value?.fieldError('email')"
          />
          <BaseInput v-if="passwordStep" v-model="password" label="Password" type="password" autocomplete="current-password" required />
          <BaseButton v-if="passwordStep" type="submit" label="Sign in" :loading="login.signIn.loading.value" />
          <BaseButton v-else type="submit" label="Continue" :loading="login.discover.loading.value" />
        </form>

        <div v-if="details.identity_providers.length > 0" class="flex flex-col gap-2">
          <p class="text-center text-xs text-text-muted">or</p>
          <BaseButton
            v-for="provider in details.identity_providers"
            :key="provider.uid"
            :label="`Continue with ${provider.name}`"
            variant="secondary"
            @click="login.navigate(login.providerUrl(provider.uid))"
          />
        </div>

        <div class="flex flex-wrap justify-between gap-2">
          <BaseButton label="Forgot your password?" variant="ghost" size="sm" @click="show('forgot-password')" />
          <BaseButton v-if="details.allow_self_sign_up" label="Create an account" variant="ghost" size="sm" @click="show('sign-up')" />
        </div>
      </template>

      <HostedChallengeForm
        v-else-if="step === 'challenge' && challenge"
        :challenge="challenge"
        :enrollment="enrollment"
        :error="login.answer.error.value"
        :loading="login.answer.loading.value"
        @submit="(response) => login.answer.run(response)"
        @start-over="show('sign-in')"
      />

      <div v-else-if="step === 'recovery-codes'" class="flex flex-col gap-4">
        <RecoveryCodesList :codes="recoveryCodes" />
        <BaseButton label="I've saved my codes" @click="login.continueAfterRecoveryCodes()" />
      </div>

      <form v-else-if="step === 'sign-up'" class="flex flex-col gap-4" novalidate @submit.prevent="login.signUp.run({ name, password })">
        <BaseAlert v-if="login.signUp.error.value && login.signUp.error.value.details.length === 0" variant="danger">
          {{ login.signUp.error.value.message }}
        </BaseAlert>
        <BaseInput v-model="name" label="Name" autocomplete="name" :error="login.signUp.error.value?.fieldError('name')" />
        <BaseInput v-model="email" label="Email" type="email" autocomplete="email" required :error="login.signUp.error.value?.fieldError('email')" />
        <BaseInput
          v-model="password"
          label="Password"
          type="password"
          autocomplete="new-password"
          required
          :error="login.signUp.error.value?.fieldError('password')"
        />
        <div class="flex flex-wrap gap-2">
          <BaseButton type="submit" label="Create account" :loading="login.signUp.loading.value" />
          <BaseButton label="I already have an account" variant="secondary" @click="show('sign-in')" />
        </div>
      </form>

      <form v-else-if="step === 'confirm-sign-up'" class="flex flex-col gap-4" novalidate @submit.prevent="login.confirmSignUp.run(code)">
        <p class="text-sm text-text-muted">
          If {{ email }} can be used for a new account, we've sent it a 6-digit code. If you already have an account, check your
          email for a reminder instead.
        </p>
        <BaseAlert v-if="login.confirmSignUp.error.value && login.confirmSignUp.error.value.details.length === 0" variant="danger">
          {{ login.confirmSignUp.error.value.message }}
        </BaseAlert>
        <BaseAlert v-if="login.resendConfirmation.error.value" variant="danger">{{ login.resendConfirmation.error.value.message }}</BaseAlert>
        <BaseInput v-model="code" label="Code" autocomplete="one-time-code" inputmode="numeric" required :error="login.confirmSignUp.error.value?.fieldError('code')" />
        <div class="flex flex-wrap gap-2">
          <BaseButton type="submit" label="Confirm" :loading="login.confirmSignUp.loading.value" />
          <BaseButton label="Send a new code" variant="secondary" :loading="login.resendConfirmation.loading.value" @click="login.resendConfirmation.run()" />
          <BaseButton label="Back to sign-in" variant="ghost" @click="show('sign-in')" />
        </div>
      </form>

      <form v-else-if="step === 'forgot-password'" class="flex flex-col gap-4" novalidate @submit.prevent="login.forgotPassword.run()">
        <p class="text-sm text-text-muted">Enter your email and we'll send you a code to choose a new password.</p>
        <BaseAlert v-if="login.forgotPassword.error.value && login.forgotPassword.error.value.details.length === 0" variant="danger">
          {{ login.forgotPassword.error.value.message }}
        </BaseAlert>
        <BaseInput v-model="email" label="Email" type="email" autocomplete="username" required :error="login.forgotPassword.error.value?.fieldError('email')" />
        <div class="flex flex-wrap gap-2">
          <BaseButton type="submit" label="Send code" :loading="login.forgotPassword.loading.value" />
          <BaseButton label="Back to sign-in" variant="ghost" @click="show('sign-in')" />
        </div>
      </form>

      <form
        v-else-if="step === 'reset-password'"
        class="flex flex-col gap-4"
        novalidate
        @submit.prevent="login.resetPassword.run({ code, password: newPassword })"
      >
        <p class="text-sm text-text-muted">If {{ email }} has an account, we've sent it a 6-digit code.</p>
        <BaseAlert v-if="login.resetPassword.error.value && login.resetPassword.error.value.details.length === 0" variant="danger">
          {{ login.resetPassword.error.value.message }}
        </BaseAlert>
        <BaseInput v-model="code" label="Code" autocomplete="one-time-code" inputmode="numeric" required :error="login.resetPassword.error.value?.fieldError('code')" />
        <BaseInput
          v-model="newPassword"
          label="New password"
          type="password"
          autocomplete="new-password"
          required
          :error="login.resetPassword.error.value?.fieldError('password')"
        />
        <div class="flex flex-wrap gap-2">
          <BaseButton type="submit" label="Change password" :loading="login.resetPassword.loading.value" />
          <BaseButton label="Back to sign-in" variant="ghost" @click="show('sign-in')" />
        </div>
      </form>
    </template>
  </BaseCard>
</template>
