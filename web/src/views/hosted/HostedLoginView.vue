<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'

import AccountLookupState from '@/components/auth/AccountLookupState.vue'
import RecoveryCodesList from '@/components/auth/RecoveryCodesList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import HostedChallengeForm from '@/components/hosted/HostedChallengeForm.vue'
import { useHostedProject } from '@/composables/useHostedProject'
import { useHostedLogin } from '@/composables/useHostedLogin'
import { errorMessage } from '@/services/http'
import { resumedChallenge } from '@/utils/resumedChallenge'
import { passkeysSupported } from '@/utils/webauthn'

const route = useRoute()
const { t } = useI18n()
const { account, projectUid, loading: accountLoading, error: accountError } = useHostedProject()
const login = useHostedLogin()
const { details, step, email, challenge, enrollment, recoveryCodes, notice, passwordStep } = login

const password = ref('')
const name = ref('')
const code = ref('')
const newPassword = ref('')

const query = (key: string) => (typeof route.query[key] === 'string' ? (route.query[key] as string) : '')
const providerError = ref(query('error') ? errorMessage(query('error')) : '')

const title = computed(() => {
  const project = details.value?.project_name ?? t('hosted.login.yourAccount')
  switch (step.value) {
    case 'challenge':
      if (challenge.value?.challenge === 'mfa_setup') return t('signIn.headings.mfaSetup')
      return challenge.value?.challenge === 'new_password' ? t('signIn.headings.newPassword') : t('signIn.headings.otp')
    case 'recovery-codes':
      return t('signIn.headings.mfaOn')
    case 'sign-up':
      return t('hosted.login.createAccountTitle', { project })
    case 'confirm-sign-up':
      return t('hosted.login.confirmEmail')
    case 'forgot-password':
    case 'reset-password':
      return t('hosted.login.resetPassword')
    default:
      return t('hosted.login.signInTo', { project })
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
    const resume = resumedChallenge(query('challenge'), query('session'), query('mfa_methods'))
    login.load.run({ accountUid: loaded.uid, projectUid: projectUid.value, interaction: query('interaction') }, resume)
  },
  { immediate: true },
)
</script>

<template>
  <BaseCard :title="title" :description="step === 'sign-in' && details ? t('hosted.login.toContinue', { app: details.app_name }) : undefined">
    <AccountLookupState :loading="accountLoading" :error="accountError" />

    <BaseAlert v-if="interactionExpired" variant="warning" :title="t('hosted.login.expiredTitle')">
      {{ t('hosted.login.expired') }}
    </BaseAlert>
    <BaseAlert v-else-if="login.load.error.value" variant="danger">{{ login.load.error.value.message }}</BaseAlert>
    <p v-else-if="login.load.loading.value" class="text-sm text-text-muted" role="status">{{ t('common.loading') }}</p>

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
            :label="t('signIn.email')"
            type="email"
            :autocomplete="details.passkeys ? 'username webauthn' : 'username'"
            required
            :error="login.signIn.error.value?.fieldError('email') ?? login.discover.error.value?.fieldError('email')"
          />
          <BaseInput v-if="passwordStep" v-model="password" :label="t('signIn.password')" type="password" autocomplete="current-password" required />
          <BaseButton v-if="passwordStep" type="submit" :label="t('signIn.signIn')" :loading="login.signIn.loading.value" />
          <BaseButton v-else type="submit" :label="t('signIn.continue')" :loading="login.discover.loading.value" />
        </form>

        <template v-if="details.passkeys && passkeysSupported()">
          <BaseAlert v-if="login.signInWithPasskey.error.value" variant="danger">{{ login.signInWithPasskey.error.value.message }}</BaseAlert>
          <BaseAlert v-else-if="login.passkeyError.value" variant="danger">{{ login.passkeyError.value }}</BaseAlert>
          <BaseButton :label="t('signIn.withPasskey')" variant="secondary" :loading="login.signInWithPasskey.loading.value" @click="login.signInWithPasskey.run()" />
        </template>

        <div v-if="details.identity_providers.length > 0" class="flex flex-col gap-2">
          <p class="text-center text-xs text-text-muted">{{ t('hosted.login.or') }}</p>
          <BaseButton
            v-for="provider in details.identity_providers"
            :key="provider.uid"
            :label="t('hosted.login.continueWith', { provider: provider.name })"
            variant="secondary"
            @click="login.navigate(login.providerUrl(provider.uid))"
          />
        </div>

        <div class="flex flex-wrap justify-between gap-2">
          <BaseButton :label="t('signIn.forgotPassword')" variant="ghost" size="sm" @click="show('forgot-password')" />
          <BaseButton v-if="details.allow_self_sign_up" :label="t('hosted.login.createAccount')" variant="ghost" size="sm" @click="show('sign-up')" />
        </div>
      </template>

      <HostedChallengeForm
        v-else-if="step === 'challenge' && challenge"
        :challenge="challenge"
        :enrollment="enrollment"
        :error="login.answer.error.value ?? login.answerWithPasskey.error.value"
        :loading="login.answer.loading.value"
        :passkey-loading="login.answerWithPasskey.loading.value"
        :passkey-error="login.passkeyError.value"
        @submit="(response) => login.answer.run(response)"
        @passkey="login.answerWithPasskey.run()"
        @start-over="show('sign-in')"
      />

      <div v-else-if="step === 'recovery-codes'" class="flex flex-col gap-4">
        <RecoveryCodesList :codes="recoveryCodes" />
        <BaseButton :label="t('signIn.savedCodes')" @click="login.continueAfterRecoveryCodes()" />
      </div>

      <form v-else-if="step === 'sign-up'" class="flex flex-col gap-4" novalidate @submit.prevent="login.signUp.run({ name, password })">
        <BaseAlert v-if="login.signUp.error.value && login.signUp.error.value.details.length === 0" variant="danger">
          {{ login.signUp.error.value.message }}
        </BaseAlert>
        <BaseInput v-model="name" :label="t('hosted.login.name')" autocomplete="name" :error="login.signUp.error.value?.fieldError('name')" />
        <BaseInput v-model="email" :label="t('signIn.email')" type="email" autocomplete="email" required :error="login.signUp.error.value?.fieldError('email')" />
        <BaseInput
          v-model="password"
          :label="t('signIn.password')"
          type="password"
          autocomplete="new-password"
          required
          :error="login.signUp.error.value?.fieldError('password')"
        />
        <div class="flex flex-wrap gap-2">
          <BaseButton type="submit" :label="t('hosted.login.submitSignUp')" :loading="login.signUp.loading.value" />
          <BaseButton :label="t('hosted.login.haveAccount')" variant="secondary" @click="show('sign-in')" />
        </div>
      </form>

      <form v-else-if="step === 'confirm-sign-up'" class="flex flex-col gap-4" novalidate @submit.prevent="login.confirmSignUp.run(code)">
        <p class="text-sm text-text-muted">{{ t('hosted.login.signUpSent', { email }) }}</p>
        <BaseAlert v-if="login.confirmSignUp.error.value && login.confirmSignUp.error.value.details.length === 0" variant="danger">
          {{ login.confirmSignUp.error.value.message }}
        </BaseAlert>
        <BaseAlert v-if="login.resendConfirmation.error.value" variant="danger">{{ login.resendConfirmation.error.value.message }}</BaseAlert>
        <BaseInput v-model="code" :label="t('hosted.login.code')" autocomplete="one-time-code" inputmode="numeric" required :error="login.confirmSignUp.error.value?.fieldError('code')" />
        <div class="flex flex-wrap gap-2">
          <BaseButton type="submit" :label="t('hosted.login.confirm')" :loading="login.confirmSignUp.loading.value" />
          <BaseButton :label="t('hosted.login.sendNewCode')" variant="secondary" :loading="login.resendConfirmation.loading.value" @click="login.resendConfirmation.run()" />
          <BaseButton :label="t('hosted.login.backToSignIn')" variant="ghost" @click="show('sign-in')" />
        </div>
      </form>

      <form v-else-if="step === 'forgot-password'" class="flex flex-col gap-4" novalidate @submit.prevent="login.forgotPassword.run()">
        <p class="text-sm text-text-muted">{{ t('hosted.login.forgotPassword') }}</p>
        <BaseAlert v-if="login.forgotPassword.error.value && login.forgotPassword.error.value.details.length === 0" variant="danger">
          {{ login.forgotPassword.error.value.message }}
        </BaseAlert>
        <BaseInput v-model="email" :label="t('signIn.email')" type="email" autocomplete="username" required :error="login.forgotPassword.error.value?.fieldError('email')" />
        <div class="flex flex-wrap gap-2">
          <BaseButton type="submit" :label="t('hosted.login.sendCode')" :loading="login.forgotPassword.loading.value" />
          <BaseButton :label="t('hosted.login.backToSignIn')" variant="ghost" @click="show('sign-in')" />
        </div>
      </form>

      <form
        v-else-if="step === 'reset-password'"
        class="flex flex-col gap-4"
        novalidate
        @submit.prevent="login.resetPassword.run({ code, password: newPassword })"
      >
        <p class="text-sm text-text-muted">{{ t('hosted.login.resetSent', { email }) }}</p>
        <BaseAlert v-if="login.resetPassword.error.value && login.resetPassword.error.value.details.length === 0" variant="danger">
          {{ login.resetPassword.error.value.message }}
        </BaseAlert>
        <BaseInput v-model="code" :label="t('hosted.login.code')" autocomplete="one-time-code" inputmode="numeric" required :error="login.resetPassword.error.value?.fieldError('code')" />
        <BaseInput
          v-model="newPassword"
          :label="t('signIn.newPassword')"
          type="password"
          autocomplete="new-password"
          required
          :error="login.resetPassword.error.value?.fieldError('password')"
        />
        <div class="flex flex-wrap gap-2">
          <BaseButton type="submit" :label="t('hosted.login.changePassword')" :loading="login.resetPassword.loading.value" />
          <BaseButton :label="t('hosted.login.backToSignIn')" variant="ghost" @click="show('sign-in')" />
        </div>
      </form>
    </template>
  </BaseCard>
</template>
