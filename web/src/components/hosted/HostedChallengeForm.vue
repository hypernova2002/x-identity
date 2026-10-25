<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import OtpSetup from '@/components/auth/OtpSetup.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import type { ApiError } from '@/services/http'
import type { MfaEnrollment, SignInChallenge } from '@/types/api'
import { passkeysSupported } from '@/utils/webauthn'

const props = withDefaults(
  defineProps<{
    challenge: SignInChallenge
    enrollment: MfaEnrollment | null
    error: ApiError | null
    loading: boolean
    passkeyLoading?: boolean
    /** Why the last passkey attempt failed, when it wasn't an API error. */
    passkeyError?: string | null
  }>(),
  { passkeyLoading: false, passkeyError: null },
)

const emit = defineEmits<{
  submit: [response: { code?: string; newPassword?: string }]
  /** The user chose to answer with a passkey. */
  passkey: []
  startOver: []
}>()

const offersPasskey = computed(() => passkeysSupported() && (props.challenge.mfa_methods ?? []).includes('passkey'))

const code = ref('')
const newPassword = ref('')

watch(
  () => props.challenge.session,
  () => {
    code.value = ''
    newPassword.value = ''
  },
)
</script>

<template>
  <form class="flex flex-col gap-4" novalidate @submit.prevent="emit('submit', { code, newPassword })">
    <BaseAlert v-if="error && error.details.length === 0" variant="danger">{{ error.message }}</BaseAlert>
    <BaseAlert v-if="passkeyError" variant="danger">{{ passkeyError }}</BaseAlert>

    <template v-if="challenge.challenge === 'passkey'">
      <p class="text-sm text-text-muted">Confirm it's you with your passkey: your fingerprint, face or device PIN.</p>
      <p v-if="!offersPasskey" class="text-sm text-text-muted">This browser doesn't support passkeys. Try another browser or device.</p>
    </template>

    <template v-else-if="challenge.challenge === 'otp'">
      <p class="text-sm text-text-muted">Enter the code from your authenticator app or security token, or one of your recovery codes.</p>
      <BaseInput v-model="code" label="Verification code" autocomplete="one-time-code" required :error="error?.fieldError('code')" />
    </template>

    <template v-else-if="challenge.challenge === 'new_password'">
      <p class="text-sm text-text-muted">Your password has expired. Choose a new one to continue.</p>
      <BaseInput
        v-model="newPassword"
        label="New password"
        type="password"
        autocomplete="new-password"
        required
        :error="error?.fieldError('new_password')"
      />
    </template>

    <template v-else-if="challenge.challenge === 'mfa_setup'">
      <p class="text-sm text-text-muted">Multi-factor authentication is required. Set it up to continue.</p>
      <OtpSetup v-if="enrollment" :enrollment="enrollment" />
      <BaseInput
        v-model="code"
        label="Verification code"
        autocomplete="one-time-code"
        inputmode="numeric"
        required
        :error="error?.fieldError('code')"
      />
    </template>

    <div class="flex flex-wrap gap-2">
      <template v-if="error?.code !== 'invalid_challenge'">
        <BaseButton v-if="challenge.challenge === 'passkey'" label="Use your passkey" :disabled="!offersPasskey" :loading="passkeyLoading" @click="emit('passkey')" />
        <template v-else>
          <BaseButton type="submit" label="Continue" :loading="loading" />
          <BaseButton v-if="offersPasskey" label="Use your passkey instead" variant="secondary" :loading="passkeyLoading" @click="emit('passkey')" />
        </template>
      </template>
      <BaseButton label="Start over" variant="secondary" @click="emit('startOver')" />
    </div>
  </form>
</template>
