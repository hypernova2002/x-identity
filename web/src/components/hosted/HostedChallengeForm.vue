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

const supportsPasskeys = passkeysSupported()
const offersPasskey = computed(() => supportsPasskeys && (props.challenge.mfa_methods ?? []).includes('passkey'))

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

    <template v-if="challenge.challenge === 'passkey_setup'">
      <p class="text-sm text-text-muted">{{ $t('signIn.challenges.hostedPasskeySetup') }}</p>
      <p v-if="!supportsPasskeys" class="text-sm text-text-muted">{{ $t('signIn.challenges.noPasskeys') }}</p>
    </template>

    <template v-else-if="challenge.challenge === 'passkey'">
      <p class="text-sm text-text-muted">{{ $t('signIn.challenges.passkey') }}</p>
      <p v-if="!offersPasskey" class="text-sm text-text-muted">{{ $t('signIn.challenges.noPasskeys') }}</p>
    </template>

    <template v-else-if="challenge.challenge === 'otp'">
      <p class="text-sm text-text-muted">{{ $t('signIn.challenges.hostedOtp') }}</p>
      <BaseInput v-model="code" :label="$t('signIn.verificationCode')" autocomplete="one-time-code" required :error="error?.fieldError('code')" />
    </template>

    <template v-else-if="challenge.challenge === 'new_password'">
      <p class="text-sm text-text-muted">{{ $t('signIn.challenges.newPassword') }}</p>
      <BaseInput
        v-model="newPassword"
        :label="$t('signIn.newPassword')"
        type="password"
        autocomplete="new-password"
        required
        :error="error?.fieldError('new_password')"
      />
    </template>

    <template v-else-if="challenge.challenge === 'mfa_setup'">
      <p class="text-sm text-text-muted">{{ $t('signIn.challenges.hostedMfaSetup') }}</p>
      <OtpSetup v-if="enrollment" :enrollment="enrollment" />
      <BaseInput
        v-model="code"
        :label="$t('signIn.verificationCode')"
        autocomplete="one-time-code"
        inputmode="numeric"
        required
        :error="error?.fieldError('code')"
      />
    </template>

    <div class="flex flex-wrap gap-2">
      <template v-if="error?.code !== 'invalid_challenge'">
        <BaseButton
          v-if="challenge.challenge === 'passkey_setup'"
          :label="$t('signIn.createPasskey')"
          :disabled="!supportsPasskeys"
          :loading="passkeyLoading"
          @click="emit('passkey')"
        />
        <BaseButton v-else-if="challenge.challenge === 'passkey'" :label="$t('signIn.usePasskey')" :disabled="!offersPasskey" :loading="passkeyLoading" @click="emit('passkey')" />
        <template v-else>
          <BaseButton type="submit" :label="$t('signIn.continue')" :loading="loading" />
          <BaseButton v-if="offersPasskey" :label="$t('signIn.usePasskeyInstead')" variant="secondary" :loading="passkeyLoading" @click="emit('passkey')" />
        </template>
      </template>
      <BaseButton :label="$t('signIn.startOver')" variant="secondary" @click="emit('startOver')" />
    </div>
  </form>
</template>
