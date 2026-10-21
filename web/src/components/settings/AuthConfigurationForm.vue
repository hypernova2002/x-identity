<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import type { AuthConfiguration, MfaRequirement, OtpType, SigningAlgorithm } from '@/types/api'
import { formatDuration } from '@/utils/format'
import { mfaRequirementOptions, signingAlgorithmOptions } from '@/utils/options'

type NumberField =
  | 'password_min_length'
  | 'password_max_age_seconds'
  | 'lockout_threshold'
  | 'lockout_window_seconds'
  | 'lockout_duration_seconds'
  | 'access_token_ttl_seconds'
  | 'refresh_token_ttl_seconds'
  | 'session_idle_timeout_seconds'
  | 'signing_key_rotation_seconds'
  | 'mfa_max_failed_attempts'
  | 'email_code_max_attempts'
  | 'email_code_max_failures_per_email'
  | 'email_code_max_failures_per_code'
  | 'email_code_failure_window_seconds'
  | 'otp_digits'
  | 'otp_step_seconds'
  | 'otp_drift_steps'
  | 'otp_hotp_look_ahead'

const OPTIONAL_FIELDS: NumberField[] = ['password_max_age_seconds', 'session_idle_timeout_seconds']

const props = defineProps<{
  load: () => Promise<AuthConfiguration>
  save: (changes: Partial<AuthConfiguration>) => Promise<AuthConfiguration>
  readonly?: boolean
  emailVerificationHint: string
  showEmailCodeLimits?: boolean
}>()

const mfaRequirement = ref<MfaRequirement>('optional')
const signingAlgorithm = ref<SigningAlgorithm>('ES256')
const flags = ref({
  require_email_verification: false,
  password_require_uppercase: false,
  password_require_lowercase: false,
  password_require_number: false,
  password_require_symbol: false,
})
const numbers = ref<Record<NumberField, string>>({
  password_min_length: '',
  password_max_age_seconds: '',
  lockout_threshold: '',
  lockout_window_seconds: '',
  lockout_duration_seconds: '',
  access_token_ttl_seconds: '',
  refresh_token_ttl_seconds: '',
  session_idle_timeout_seconds: '',
  signing_key_rotation_seconds: '',
  mfa_max_failed_attempts: '',
  email_code_max_attempts: '',
  email_code_max_failures_per_email: '',
  email_code_max_failures_per_code: '',
  email_code_failure_window_seconds: '',
  otp_digits: '',
  otp_step_seconds: '',
  otp_drift_steps: '',
  otp_hotp_look_ahead: '',
})
const otpMethods = ref<OtpType[]>(['totp'])
const unusualOtpFormat = computed(() => numbers.value.otp_digits.trim() !== '6' || numbers.value.otp_step_seconds.trim() !== '30')

function setOtpMethod(method: OtpType, allowed: boolean) {
  otpMethods.value = allowed ? [...new Set([...otpMethods.value, method])] : otpMethods.value.filter((existing) => existing !== method)
}
const saved = ref(false)

function apply(configuration: AuthConfiguration) {
  mfaRequirement.value = configuration.mfa_requirement
  otpMethods.value = [...configuration.otp_methods]
  signingAlgorithm.value = configuration.signing_algorithm
  flags.value = {
    require_email_verification: configuration.require_email_verification,
    password_require_uppercase: configuration.password_require_uppercase,
    password_require_lowercase: configuration.password_require_lowercase,
    password_require_number: configuration.password_require_number,
    password_require_symbol: configuration.password_require_symbol,
  }
  for (const field of Object.keys(numbers.value) as NumberField[]) {
    numbers.value[field] = configuration[field] === null ? '' : String(configuration[field])
  }
}

/** The hint under a duration field: what the entered seconds amount to, and the allowed range. */
function durationHint(field: NumberField, range: string, note = ''): string {
  const seconds = Number(numbers.value[field])
  const amount = numbers.value[field].trim() !== '' && Number.isFinite(seconds) ? `${formatDuration(seconds)}. ` : ''
  return `${amount}${range}${note ? ` ${note}` : ''}`
}

function numberValue(field: NumberField): number | null {
  const raw = numbers.value[field].trim()
  if (raw === '' && OPTIONAL_FIELDS.includes(field)) return null
  return Number(raw)
}

const load = useAsyncAction(async () => {
  apply(await props.load())
})

const save = useAsyncAction(async () => {
  saved.value = false

  const changes: Partial<AuthConfiguration> = {
    mfa_requirement: mfaRequirement.value,
    otp_methods: otpMethods.value,
    signing_algorithm: signingAlgorithm.value,
    ...flags.value,
  }
  for (const field of Object.keys(numbers.value) as NumberField[]) {
    Object.assign(changes, { [field]: numberValue(field) })
  }

  apply(await props.save(changes))
  saved.value = true
})

onMounted(() => load.run())
</script>

<template>
  <p v-if="load.loading.value" class="text-sm text-text-muted" role="status">Loading settings…</p>
  <BaseAlert v-else-if="load.error.value" variant="danger">We couldn't load the settings. {{ load.error.value.message }}</BaseAlert>

  <form v-else class="flex flex-col gap-6" novalidate @submit.prevent="save.run()">
    <BaseAlert v-if="readonly" variant="info">Only project and account admins can change these settings.</BaseAlert>
    <fieldset :disabled="readonly" class="contents">
    <BaseAlert v-if="saved" variant="success">Settings saved.</BaseAlert>
    <BaseAlert v-if="save.error.value" variant="danger">
      {{ save.error.value.message }} Check the highlighted fields.
    </BaseAlert>

    <BaseCard title="Multi-factor authentication">
      <BaseSelect
        v-model="mfaRequirement"
        label="Requirement"
        :options="mfaRequirementOptions"
        hint="When required, users without an authenticator app are asked to set one up at their next sign-in."
        :error="save.error.value?.fieldError('mfa_requirement')"
      />
      <BaseInput
        v-model="numbers.mfa_max_failed_attempts"
        label="Wrong codes before the user is disabled"
        type="number"
        hint="3–20 consecutive wrong authenticator or recovery codes. Admins can re-enable disabled users."
        :error="save.error.value?.fieldError('mfa_max_failed_attempts')"
      />

      <fieldset class="flex flex-col gap-3">
        <legend class="mb-1 text-sm font-semibold">Methods</legend>
        <BaseCheckbox
          :model-value="otpMethods.includes('totp')"
          label="Authenticator apps (time-based codes, TOTP)"
          @update:model-value="(allowed: boolean) => setOtpMethod('totp', allowed)"
        />
        <BaseCheckbox
          :model-value="otpMethods.includes('hotp')"
          label="Hardware tokens (counter-based codes, HOTP)"
          @update:model-value="(allowed: boolean) => setOtpMethod('hotp', allowed)"
        />
        <p v-if="save.error.value?.fieldError('otp_methods')" class="text-xs font-medium text-danger">
          Error: {{ save.error.value?.fieldError('otp_methods') }}
        </p>
      </fieldset>

      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput
          v-model="numbers.otp_digits"
          label="Code length (digits)"
          type="number"
          hint="6–10. Applies to new setups only."
          :error="save.error.value?.fieldError('otp_digits')"
        />
        <BaseInput
          v-model="numbers.otp_step_seconds"
          label="Code lifetime (seconds)"
          type="number"
          :hint="durationHint('otp_step_seconds', '30–900 seconds.', 'Time-based codes only; applies to new setups only.')"
          :error="save.error.value?.fieldError('otp_step_seconds')"
        />
        <BaseInput
          v-model="numbers.otp_drift_steps"
          label="Clock drift allowed (steps)"
          type="number"
          hint="0–2 codes either side of the current one, for clocks that are slightly off."
          :error="save.error.value?.fieldError('otp_drift_steps')"
        />
        <BaseInput
          v-model="numbers.otp_hotp_look_ahead"
          label="Hardware token look-ahead"
          type="number"
          hint="1–20 codes ahead, for tokens pressed without signing in."
          :error="save.error.value?.fieldError('otp_hotp_look_ahead')"
        />
      </div>
      <BaseAlert v-if="unusualOtpFormat" variant="warning" title="Check your users' apps">
        Google Authenticator and Microsoft Authenticator only support 6-digit codes that change every 30 seconds. With other
        values they may show codes that never work.
      </BaseAlert>
    </BaseCard>

    <BaseCard
      v-if="showEmailCodeLimits"
      title="Email codes"
      description="Limits on wrong 6-digit codes from confirmation, password reset and invitation emails. Codes never disable a user; once a limit is reached, codes are refused until the window has passed."
    >
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput
          v-model="numbers.email_code_max_attempts"
          label="Wrong guesses per code"
          type="number"
          hint="3–10. The code then stops working."
          :error="save.error.value?.fieldError('email_code_max_attempts')"
        />
        <BaseInput
          v-model="numbers.email_code_max_failures_per_email"
          label="Wrong codes per address"
          type="number"
          hint="3–100 within the window, across every code sent to the address."
          :error="save.error.value?.fieldError('email_code_max_failures_per_email')"
        />
        <BaseInput
          v-model="numbers.email_code_max_failures_per_code"
          label="Tries of the same code"
          type="number"
          hint="2–100 within the window, across all addresses. Stops one guess being tried on many accounts."
          :error="save.error.value?.fieldError('email_code_max_failures_per_code')"
        />
        <BaseInput
          v-model="numbers.email_code_failure_window_seconds"
          label="Window (seconds)"
          type="number"
          :hint="durationHint('email_code_failure_window_seconds', '300–86400 seconds.')"
          :error="save.error.value?.fieldError('email_code_failure_window_seconds')"
        />
      </div>
    </BaseCard>

    <BaseCard title="Email verification">
      <BaseCheckbox
        v-model="flags.require_email_verification"
        label="Require a verified email before signing in"
        :hint="emailVerificationHint"
      />
    </BaseCard>

    <BaseCard title="Password rules">
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput
          v-model="numbers.password_min_length"
          label="Minimum length"
          type="number"
          hint="8–128 characters."
          :error="save.error.value?.fieldError('password_min_length')"
        />
        <BaseInput
          v-model="numbers.password_max_age_seconds"
          label="Maximum age (seconds)"
          type="number"
          :hint="durationHint('password_max_age_seconds', '1 to 365 days.', 'Leave empty to never expire passwords.')"
          :error="save.error.value?.fieldError('password_max_age_seconds')"
        />
      </div>
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseCheckbox v-model="flags.password_require_uppercase" label="Require an uppercase letter" />
        <BaseCheckbox v-model="flags.password_require_lowercase" label="Require a lowercase letter" />
        <BaseCheckbox v-model="flags.password_require_number" label="Require a number" />
        <BaseCheckbox v-model="flags.password_require_symbol" label="Require a symbol" />
      </div>
    </BaseCard>

    <BaseCard title="Lockout" description="Locks an email address after repeated failed sign-in or verification attempts.">
      <div class="grid gap-4 sm:grid-cols-3">
        <BaseInput
          v-model="numbers.lockout_threshold"
          label="Failed attempts"
          type="number"
          hint="3–100."
          :error="save.error.value?.fieldError('lockout_threshold')"
        />
        <BaseInput
          v-model="numbers.lockout_window_seconds"
          label="Within (seconds)"
          type="number"
          :hint="durationHint('lockout_window_seconds', '60–86400 seconds.')"
          :error="save.error.value?.fieldError('lockout_window_seconds')"
        />
        <BaseInput
          v-model="numbers.lockout_duration_seconds"
          label="Lock for (seconds)"
          type="number"
          :hint="durationHint('lockout_duration_seconds', '60–86400 seconds.')"
          :error="save.error.value?.fieldError('lockout_duration_seconds')"
        />
      </div>
    </BaseCard>

    <BaseCard title="Sessions and tokens">
      <div class="grid gap-4 sm:grid-cols-3">
        <BaseInput
          v-model="numbers.access_token_ttl_seconds"
          label="Access token lifetime (seconds)"
          type="number"
          :hint="durationHint('access_token_ttl_seconds', '300–3600 seconds.')"
          :error="save.error.value?.fieldError('access_token_ttl_seconds')"
        />
        <BaseInput
          v-model="numbers.refresh_token_ttl_seconds"
          label="Session lifetime (seconds)"
          type="number"
          :hint="durationHint('refresh_token_ttl_seconds', '1 to 365 days.', 'Users sign in again after this.')"
          :error="save.error.value?.fieldError('refresh_token_ttl_seconds')"
        />
        <BaseInput
          v-model="numbers.session_idle_timeout_seconds"
          label="Idle timeout (seconds)"
          type="number"
          :hint="durationHint('session_idle_timeout_seconds', '5 minutes to 30 days.', 'Leave empty for no idle timeout.')"
          :error="save.error.value?.fieldError('session_idle_timeout_seconds')"
        />
      </div>
    </BaseCard>

    <BaseCard title="Token signing">
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseSelect
          v-model="signingAlgorithm"
          label="Signing algorithm"
          :options="signingAlgorithmOptions"
          hint="Changing it creates a new key. Tokens signed with the old key stay valid until they expire."
          :error="save.error.value?.fieldError('signing_algorithm')"
        />
        <BaseInput
          v-model="numbers.signing_key_rotation_seconds"
          label="Rotate keys every (seconds)"
          type="number"
          :hint="durationHint('signing_key_rotation_seconds', '30 to 365 days.')"
          :error="save.error.value?.fieldError('signing_key_rotation_seconds')"
        />
      </div>
    </BaseCard>

    </fieldset>
    <BaseButton v-if="!readonly" type="submit" label="Save settings" :loading="save.loading.value" class="self-start" />
  </form>
</template>
