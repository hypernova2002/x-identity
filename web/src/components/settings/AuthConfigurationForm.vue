<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import type { AuthConfiguration, MfaRequirement, OtpType, PasskeysSetting, SigningAlgorithm } from '@/types/api'
import { AUTH_SETTINGS_FIELDS, EMAIL_CODE_FIELDS, pickFields, type AuthSettingsField, type AuthSettingsSection } from '@/utils/authSettings'
import { formatDuration } from '@/utils/format'
import { mfaRequirementOptions, otpMethodOptions, passkeysOptions, signingAlgorithmOptions } from '@/utils/options'

type NumberField =
  | 'password_min_length'
  | 'password_max_age_seconds'
  | 'lockout_threshold'
  | 'lockout_window_seconds'
  | 'lockout_duration_seconds'
  | 'access_token_ttl_seconds'
  | 'refresh_token_ttl_seconds'
  | 'session_idle_timeout_seconds'
  | 'sso_session_ttl_seconds'
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
  | 'client_secret_rotation_overlap_seconds'
  | 'token_requests_per_minute'

const OPTIONAL_FIELDS: NumberField[] = ['password_max_age_seconds', 'session_idle_timeout_seconds']
const ALL_SECTIONS: AuthSettingsSection[] = ['sign-in', 'mfa', 'policies', 'tokens', 'signing']
const PROJECT_FIELDS: AuthSettingsField[] = ['sso_session_ttl_seconds', 'client_secret_rotation_overlap_seconds', 'token_requests_per_minute']

const props = withDefaults(
  defineProps<{
    load: () => Promise<AuthConfiguration>
    save: (changes: Partial<AuthConfiguration>) => Promise<AuthConfiguration>
    readonly?: boolean
    emailVerificationHint: string
    showEmailCodeLimits?: boolean
    /** A project's settings, which include the hosted login session and app client limits. */
    forProject?: boolean
    /** A project's verified custom domain, which its passkeys need; null without one. */
    customDomain?: string | null
    /** The sections to show; saving sends only their fields, so other settings are never reset. */
    sections?: AuthSettingsSection[]
  }>(),
  { readonly: false, showEmailCodeLimits: false, forProject: false, customDomain: null, sections: () => ['sign-in', 'mfa', 'policies', 'tokens', 'signing'] },
)

/** Whether the form has changes that aren't saved yet. */
const dirty = defineModel<boolean>('dirty', { default: false })

const mfaRequirement = ref<MfaRequirement>('optional')
const passkeys = ref<PasskeysSetting>('off')

/** What stops the chosen passkey setting working, before it's saved. */
const passkeysWarning = computed(() => {
  if (passkeys.value === 'off') return null
  if (props.forProject && !props.customDomain) {
    return passkeys.value === 'required'
      ? "Required needs the project's verified custom domain, which passkeys belong to. Add one in Project settings › Custom domain."
      : "Passkeys can't be used until the project has a verified custom domain, which passkeys belong to."
  }
  if (passkeys.value === 'required' && mfaRequirement.value === 'off') {
    return "Required needs multi-factor authentication to be optional or required: sign-ins where passkeys can't be used require MFA instead."
  }
  return null
})
const signingAlgorithm = ref<SigningAlgorithm>('ES256')
const flags = ref({
  require_email_verification: false,
  notify_new_devices: true,
  passwordless_after_passkey: false,
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
  sso_session_ttl_seconds: '',
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
  client_secret_rotation_overlap_seconds: '',
  token_requests_per_minute: '',
})
const otpMethod = ref<OtpType>('totp')
const saved = ref(false)
const lastSaved = ref<Partial<AuthConfiguration>>({})

const unusualOtpFormat = computed(() => numbers.value.otp_digits.trim() !== '6' || numbers.value.otp_step_seconds.trim() !== '30')
const shown = (section: AuthSettingsSection) => props.sections.includes(section)

const visibleFields = computed<AuthSettingsField[]>(() =>
  ALL_SECTIONS.filter(shown)
    .flatMap((section) => AUTH_SETTINGS_FIELDS[section])
    .filter((field) => (props.showEmailCodeLimits || !EMAIL_CODE_FIELDS.includes(field)) && (props.forProject || !PROJECT_FIELDS.includes(field))),
)

function apply(configuration: AuthConfiguration) {
  mfaRequirement.value = configuration.mfa_requirement
  passkeys.value = configuration.passkeys
  otpMethod.value = configuration.otp_method
  signingAlgorithm.value = configuration.signing_algorithm
  flags.value = {
    require_email_verification: configuration.require_email_verification,
    notify_new_devices: configuration.notify_new_devices,
    passwordless_after_passkey: configuration.passwordless_after_passkey,
    password_require_uppercase: configuration.password_require_uppercase,
    password_require_lowercase: configuration.password_require_lowercase,
    password_require_number: configuration.password_require_number,
    password_require_symbol: configuration.password_require_symbol,
  }
  for (const field of Object.keys(numbers.value) as NumberField[]) {
    numbers.value[field] = configuration[field] === null ? '' : String(configuration[field])
  }
  lastSaved.value = pickFields(currentValues(), visibleFields.value)
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

function currentValues(): Partial<AuthConfiguration> {
  const values: Partial<AuthConfiguration> = {
    mfa_requirement: mfaRequirement.value,
    passkeys: passkeys.value,
    otp_method: otpMethod.value,
    signing_algorithm: signingAlgorithm.value,
    ...flags.value,
  }
  for (const field of Object.keys(numbers.value) as NumberField[]) {
    Object.assign(values, { [field]: numberValue(field) })
  }
  return values
}

watch(
  [mfaRequirement, passkeys, otpMethod, signingAlgorithm, flags, numbers],
  () => {
    const current = pickFields(currentValues(), visibleFields.value)
    dirty.value = JSON.stringify(current) !== JSON.stringify(lastSaved.value)
  },
  { deep: true },
)

const load = useAsyncAction(async () => {
  apply(await props.load())
})

const save = useAsyncAction(async () => {
  saved.value = false
  apply(await props.save(pickFields(currentValues(), visibleFields.value)))
  dirty.value = false
  saved.value = true
})

function discard() {
  load.run()
  saved.value = false
  save.error.value = null
}

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

    <template v-if="shown('sign-in')">
      <BaseCard title="Email verification">
        <BaseCheckbox
          v-model="flags.require_email_verification"
          label="Require a verified email before signing in"
          :hint="emailVerificationHint"
        />
      </BaseCard>

      <BaseCard
        v-if="showEmailCodeLimits"
        title="Email codes"
        description="Limits on wrong 6-digit codes from confirmation, password reset and invitation emails. Codes never disable a user; once a limit is reached, codes are refused until the window has passed."
      >
        <details class="group rounded-md border border-border">
          <summary class="cursor-pointer px-3 py-2 text-sm font-medium focus-visible:outline-2 focus-visible:outline-primary">
            Advanced: guessing limits
          </summary>
          <div class="grid gap-4 border-t border-border p-3 sm:grid-cols-2">
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
        </details>
      </BaseCard>

      <BaseCard title="Passkeys">
        <BaseSelect
          v-model="passkeys"
          label="Passkeys"
          :options="passkeysOptions"
          :hint="
            forProject
              ? 'Users add passkeys from the app portal, and sign in with them on hosted login and in your apps\' own screens. Needs the project\'s custom domain, which passkeys belong to. Required: every sign-in where passkeys work must use one, and users without one create it as they sign in; elsewhere MFA is required instead, so MFA can\'t be off.'
              : 'Console users add passkeys on My security, and sign in with them. A passkey counts as multi-factor authentication. Required: every sign-in must use one, and users without one create it as they sign in; MFA can\'t be off.'
          "
          :error="save.error.value?.fieldError('passkeys')"
        />
        <BaseAlert v-if="passkeysWarning" variant="warning">{{ passkeysWarning }}</BaseAlert>
              <BaseCheckbox
          v-model="flags.passwordless_after_passkey"
          label="No passwords once a user has a passkey"
          :disabled="passkeys === 'off'"
          :hint="
            passkeys === 'off'
              ? 'Turn passkeys on first.'
              : 'Users with a passkey that works where they sign in must use it there; a correct password is refused. Where their passkey can\'t be used (e.g. an app without allowed origins), the password still works. Lost the passkey? Resetting the password by email lets them sign in for an hour to add a new one.'
          "
        />
        <p v-if="save.error.value?.fieldError('passwordless_after_passkey')" class="text-xs font-medium text-danger">
          Error: {{ save.error.value?.fieldError('passwordless_after_passkey') }}
        </p>
      </BaseCard>
    </template>

    <BaseCard v-if="shown('mfa')" title="Multi-factor authentication policy">
      <BaseSelect
        v-model="mfaRequirement"
        label="Requirement"
        :options="mfaRequirementOptions"
        hint="When required, users without an authenticator are asked to set one up at their next sign-in."
        :error="save.error.value?.fieldError('mfa_requirement')"
      />
      <BaseSelect
        v-model="otpMethod"
        label="Method"
        :options="otpMethodOptions"
        hint="Everyone sets up this method. Users who already set up the other one keep using it."
        :error="save.error.value?.fieldError('otp_method')"
      />
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
      </div>
      <BaseAlert v-if="unusualOtpFormat" variant="warning" title="Check your users' apps">
        Google Authenticator and Microsoft Authenticator only support 6-digit codes that change every 30 seconds. With other
        values they may show codes that never work.
      </BaseAlert>
      <BaseInput
        v-model="numbers.mfa_max_failed_attempts"
        label="Wrong codes before the user is disabled"
        type="number"
        hint="3–20 consecutive wrong authenticator or recovery codes. Admins can re-enable disabled users."
        :error="save.error.value?.fieldError('mfa_max_failed_attempts')"
      />
      <details class="rounded-md border border-border">
        <summary class="cursor-pointer px-3 py-2 text-sm font-medium focus-visible:outline-2 focus-visible:outline-primary">
          Advanced: code tolerance
        </summary>
        <div class="grid gap-4 border-t border-border p-3 sm:grid-cols-2">
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
      </details>
    </BaseCard>

    <template v-if="shown('policies')">
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

      <BaseCard title="Sign-in alerts">
        <BaseCheckbox
          v-model="flags.notify_new_devices"
          label="Email users about sign-ins from new devices"
          hint="Sent when someone signs in with a device and country not used in the last 90 days, with the device, approximate location and time, and how to sign it out. Never sent for a user's first sign-in."
        />
      </BaseCard>
    </template>

    <BaseCard v-if="shown('tokens')" title="Sessions and tokens">
      <div class="grid gap-4 sm:grid-cols-2">
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
          :hint="durationHint('refresh_token_ttl_seconds', '1 to 365 days.', 'Refresh tokens stop working after this; users sign in again.')"
          :error="save.error.value?.fieldError('refresh_token_ttl_seconds')"
        />
        <BaseInput
          v-model="numbers.session_idle_timeout_seconds"
          label="Idle timeout (seconds)"
          type="number"
          :hint="durationHint('session_idle_timeout_seconds', '5 minutes to 30 days.', 'Leave empty for no idle timeout.')"
          :error="save.error.value?.fieldError('session_idle_timeout_seconds')"
        />
        <BaseInput
          v-if="forProject"
          v-model="numbers.sso_session_ttl_seconds"
          label="Hosted login session (seconds)"
          type="number"
          :hint="durationHint('sso_session_ttl_seconds', '5 minutes to 30 days.', 'How long signing in on the hosted login page also signs users in to the project\'s other apps.')"
          :error="save.error.value?.fieldError('sso_session_ttl_seconds')"
        />
      </div>
      <p class="text-xs text-text-muted">
        Refresh tokens always rotate on use; reusing an old one signs out that whole session. Logging out ends the hosted login session
        and the user's SAML app sessions.
      </p>
    </BaseCard>

    <BaseCard v-if="shown('tokens') && forProject" title="App clients" description="Limits for applications calling the token endpoint, and their client secrets.">
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput
          v-model="numbers.token_requests_per_minute"
          label="Token requests per client per minute"
          type="number"
          hint="10–10,000. Requests over the limit get HTTP 429 until the next minute. Each app can set its own limit."
          :error="save.error.value?.fieldError('token_requests_per_minute')"
        />
        <BaseInput
          v-model="numbers.client_secret_rotation_overlap_seconds"
          label="Old secrets keep working after rotation for (seconds)"
          type="number"
          :hint="durationHint('client_secret_rotation_overlap_seconds', '0 to 30 days.', '0 stops the old secret at once.')"
          :error="save.error.value?.fieldError('client_secret_rotation_overlap_seconds')"
        />
      </div>
    </BaseCard>

    <BaseCard v-if="shown('signing')" title="Token signing">
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
    <div v-if="!readonly" class="flex flex-wrap items-center gap-2">
      <BaseButton type="submit" label="Save changes" :loading="save.loading.value" :disabled="!dirty" />
      <BaseButton v-if="dirty" label="Discard changes" variant="secondary" @click="discard" />
      <span v-if="dirty" class="text-sm text-text-muted" role="status">Unsaved changes</span>
    </div>
  </form>
</template>
