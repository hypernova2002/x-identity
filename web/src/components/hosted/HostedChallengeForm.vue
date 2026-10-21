<script setup lang="ts">
import { ref, watch } from 'vue'

import OtpSetup from '@/components/auth/OtpSetup.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import type { ApiError } from '@/services/http'
import type { MfaEnrollment, SignInChallenge } from '@/types/api'

const props = defineProps<{
  challenge: SignInChallenge
  enrollment: MfaEnrollment | null
  error: ApiError | null
  loading: boolean
}>()

const emit = defineEmits<{
  submit: [response: { code?: string; newPassword?: string }]
  startOver: []
}>()

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

    <template v-if="challenge.challenge === 'otp'">
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
      <BaseButton v-if="error?.code !== 'invalid_challenge'" type="submit" label="Continue" :loading="loading" />
      <BaseButton label="Start over" variant="secondary" @click="emit('startOver')" />
    </div>
  </form>
</template>
