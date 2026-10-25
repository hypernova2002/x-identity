<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import AccountLookupState from '@/components/auth/AccountLookupState.vue'
import RecoveryCodesList from '@/components/auth/RecoveryCodesList.vue'
import OtpSetup from '@/components/auth/OtpSetup.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import { useAccountFromRoute } from '@/composables/useAccountFromRoute'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { usePasskeyPrompt } from '@/composables/usePasskeyPrompt'
import { safeRedirect } from '@/router'
import { authService, isChallenge } from '@/services/auth'
import { ApiError } from '@/services/http'
import { useSessionStore } from '@/stores/session'
import type { MfaEnrollment, SignInChallenge, SignInResult, TokenSet } from '@/types/api'
import { passkeyAutofillAvailable, passkeysSupported } from '@/utils/webauthn'

const route = useRoute()
const router = useRouter()
const session = useSessionStore()
const { account, slug, loading: accountLoading, error: accountError } = useAccountFromRoute()

const email = ref('')
const password = ref('')
const code = ref('')
const newPassword = ref('')
const challenge = ref<SignInChallenge | null>(null)
const enrollment = ref<MfaEnrollment | null>(null)
const completedTokens = ref<TokenSet | null>(null)
const recoveryCodes = ref<string[]>([])
const passkeyPrompt = usePasskeyPrompt()
const passkeysOffered = computed(() => Boolean(account.value?.passkeys) && passkeysSupported())
const offersPasskeyAnswer = computed(() => passkeysSupported() && (challenge.value?.mfa_methods ?? []).includes('passkey'))

const heading = computed(() => {
  if (recoveryCodes.value.length > 0) return 'Multi-factor authentication is on'
  switch (challenge.value?.challenge) {
    case 'otp':
      return 'Enter your verification code'
    case 'passkey':
      return "Confirm it's you"
    case 'new_password':
      return 'Choose a new password'
    case 'mfa_setup':
      return 'Set up multi-factor authentication'
    default:
      return account.value ? `Sign in to ${account.value.name}` : 'Sign in'
  }
})

async function finish(tokens: TokenSet) {
  if (!account.value) return

  session.start(account.value, tokens)
  await router.push(safeRedirect(route.query.redirect))
}

async function handleResult(result: SignInResult) {
  code.value = ''
  newPassword.value = ''
  if (result.recovery_codes) recoveryCodes.value = result.recovery_codes

  if (isChallenge(result)) {
    challenge.value = result
    enrollment.value = null
    if (result.challenge === 'mfa_setup' && account.value) {
      enrollment.value = await authService.startMfaSetup(account.value.uid, result.session)
    }
    return
  }

  challenge.value = null
  if (recoveryCodes.value.length > 0) {
    completedTokens.value = result
  } else {
    await finish(result)
  }
}

const signIn = useAsyncAction(async () => {
  if (!account.value) return
  await handleResult(await authService.signIn(account.value.uid, email.value, password.value))
})

async function passkeySignIn(autofill: boolean) {
  if (!account.value) return
  const accountUid = account.value.uid
  const answer = await passkeyPrompt.prompt(() => authService.passkeyOptions(accountUid), { autofill })
  if (answer) await handleResult(await authService.passkeySignIn(accountUid, answer.authenticationId, answer.credential))
}

/** Signs in with a passkey the user picks in the browser's prompt. */
const signInWithPasskey = useAsyncAction(() => passkeySignIn(false))

/** Offers the user's passkeys in the email field's autofill, until they pick one or use the password. */
watch(
  account,
  async (loaded) => {
    if (!loaded?.passkeys || !(await passkeyAutofillAvailable())) return
    try {
      await passkeySignIn(true)
    } catch (caught) {
      signInWithPasskey.error.value = caught instanceof ApiError ? caught : new ApiError('internal_error', 'Something unexpected happened. Try again.', 0)
    }
  },
  { immediate: true },
)

/** Answers a second-factor challenge with one of the user's passkeys. */
const answerWithPasskey = useAsyncAction(async () => {
  if (!account.value || !challenge.value) return
  const accountUid = account.value.uid
  const { session } = challenge.value
  const answer = await passkeyPrompt.prompt(() => authService.passkeyChallengeOptions(accountUid, session))
  if (!answer) return
  await handleResult(
    await authService.respondToChallenge(accountUid, { challenge: 'passkey', session, authentication_id: answer.authenticationId, credential: answer.credential }),
  )
})

const answer = useAsyncAction(async () => {
  if (!account.value || !challenge.value) return

  const result = await authService.respondToChallenge(account.value.uid, {
    challenge: challenge.value.challenge,
    session: challenge.value.session,
    code: challenge.value.challenge === 'new_password' ? undefined : code.value,
    new_password: challenge.value.challenge === 'new_password' ? newPassword.value : undefined,
  })
  await handleResult(result)
})

function startOver() {
  challenge.value = null
  enrollment.value = null
  password.value = ''
  answer.error.value = null
}

const challengeExpired = computed(() => answer.error.value?.code === 'invalid_challenge')
</script>

<template>
  <BaseCard :title="heading">
    <AccountLookupState :loading="accountLoading" :error="accountError" />

    <template v-if="account">
      <div v-if="completedTokens" class="flex flex-col gap-4">
        <RecoveryCodesList :codes="recoveryCodes" />
        <BaseButton label="I've saved my codes" @click="finish(completedTokens)" />
      </div>

      <form v-else-if="!challenge" class="flex flex-col gap-4" novalidate @submit.prevent="signIn.run()">
        <BaseAlert v-if="signIn.error.value" variant="danger">{{ signIn.error.value.message }}</BaseAlert>
        <BaseInput v-model="email" label="Email" type="email" :autocomplete="account.passkeys ? 'username webauthn' : 'username'" required />
        <BaseInput v-model="password" label="Password" type="password" autocomplete="current-password" required />
        <BaseButton type="submit" label="Sign in" :loading="signIn.loading.value" />
        <template v-if="passkeysOffered">
          <BaseAlert v-if="signInWithPasskey.error.value" variant="danger">{{ signInWithPasskey.error.value.message }}</BaseAlert>
          <BaseAlert v-else-if="passkeyPrompt.error.value" variant="danger">{{ passkeyPrompt.error.value }}</BaseAlert>
          <BaseButton label="Sign in with a passkey" variant="secondary" :loading="signInWithPasskey.loading.value" @click="signInWithPasskey.run()" />
        </template>
        <div class="flex flex-wrap justify-between gap-2 text-sm">
          <RouterLink
            :to="{ name: 'forgot-password', params: { slug } }"
            class="font-medium text-primary underline hover:text-primary-hover"
          >
            Forgot your password?
          </RouterLink>
          <RouterLink to="/sign-in" class="text-text-muted underline hover:text-text">Use a different account</RouterLink>
        </div>
      </form>

      <form v-else class="flex flex-col gap-4" novalidate @submit.prevent="answer.run()">
        <BaseAlert v-if="challengeExpired" variant="danger">
          {{ answer.error.value?.message }}
        </BaseAlert>
        <BaseAlert v-else-if="answer.error.value && answer.error.value.details.length === 0" variant="danger">
          {{ answer.error.value.message }}
        </BaseAlert>
        <BaseAlert v-if="answerWithPasskey.error.value" variant="danger">{{ answerWithPasskey.error.value.message }}</BaseAlert>
        <BaseAlert v-else-if="passkeyPrompt.error.value" variant="danger">{{ passkeyPrompt.error.value }}</BaseAlert>

        <template v-if="challenge.challenge === 'passkey'">
          <p class="text-sm text-text-muted">Confirm it's you with your passkey: your fingerprint, face or device PIN.</p>
          <p v-if="!offersPasskeyAnswer" class="text-sm text-text-muted">This browser doesn't support passkeys. Try another browser or device.</p>
        </template>

        <template v-else-if="challenge.challenge === 'otp'">
          <p class="text-sm text-text-muted">Enter the code from your authenticator app, or one of your recovery codes.</p>
          <BaseInput v-model="code" label="Verification code" autocomplete="one-time-code" inputmode="numeric" required />
        </template>

        <template v-else-if="challenge.challenge === 'new_password'">
          <p class="text-sm text-text-muted">Your password has expired. Choose a new one to continue.</p>
          <BaseInput
            v-model="newPassword"
            label="New password"
            type="password"
            autocomplete="new-password"
            required
            :error="answer.error.value?.fieldError('new_password')"
          />
        </template>

        <template v-else-if="challenge.challenge === 'mfa_setup'">
          <p class="text-sm text-text-muted">Your account requires multi-factor authentication.</p>
          <OtpSetup v-if="enrollment" :enrollment="enrollment" />
          <BaseInput v-model="code" label="Verification code" autocomplete="one-time-code" inputmode="numeric" required />
        </template>

        <div class="flex flex-wrap gap-2">
          <template v-if="!challengeExpired">
            <BaseButton
              v-if="challenge.challenge === 'passkey'"
              label="Use your passkey"
              :disabled="!offersPasskeyAnswer"
              :loading="answerWithPasskey.loading.value"
              @click="answerWithPasskey.run()"
            />
            <template v-else>
              <BaseButton type="submit" label="Continue" :loading="answer.loading.value" />
              <BaseButton
                v-if="offersPasskeyAnswer"
                label="Use your passkey instead"
                variant="secondary"
                :loading="answerWithPasskey.loading.value"
                @click="answerWithPasskey.run()"
              />
            </template>
          </template>
          <BaseButton label="Start over" variant="secondary" @click="startOver" />
        </div>
      </form>
    </template>
  </BaseCard>
</template>
