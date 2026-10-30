<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

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

const { t } = useI18n()

/** Whether the form has changes that aren't saved yet. */
const dirty = defineModel<boolean>('dirty', { default: false })

const mfaRequirement = ref<MfaRequirement>('optional')
const passkeys = ref<PasskeysSetting>('off')

/** What stops the chosen passkey setting working, before it's saved. */
const passkeysWarning = computed(() => {
  if (passkeys.value === 'off') return null
  if (props.forProject && !props.customDomain) {
    return passkeys.value === 'required'
      ? t('settings.authConfiguration.customDomainRequired')
      : t('settings.authConfiguration.customDomainNeeded')
  }
  if (passkeys.value === 'required' && mfaRequirement.value === 'off') {
    return t('settings.authConfiguration.mfaNeeded')
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
  <p v-if="load.loading.value" class="text-sm text-text-muted" role="status">{{ $t('settings.authConfiguration.loadingSettings') }}</p>
  <BaseAlert v-else-if="load.error.value" variant="danger">{{ $t('settings.authConfiguration.loadFailed', { message: load.error.value.message }) }}</BaseAlert>

  <form v-else class="flex flex-col gap-6" novalidate @submit.prevent="save.run()">
    <BaseAlert v-if="readonly" variant="info">{{ $t('settings.authConfiguration.onlyProjectAndAccountAdmins') }}</BaseAlert>
    <fieldset :disabled="readonly" class="contents">
    <BaseAlert v-if="saved" variant="success">{{ $t('settings.authConfiguration.settingsSaved') }}</BaseAlert>
    <BaseAlert v-if="save.error.value" variant="danger">
      {{ $t('settings.authConfiguration.saveFailed', { message: save.error.value.message }) }}
    </BaseAlert>

    <template v-if="shown('sign-in')">
      <BaseCard :title="$t('settings.authConfiguration.emailVerification')">
        <BaseCheckbox
          v-model="flags.require_email_verification"
          :label="$t('settings.authConfiguration.requireAVerifiedEmailBefore')"
          :hint="emailVerificationHint"
        />
      </BaseCard>

      <BaseCard
        v-if="showEmailCodeLimits"
        :title="$t('settings.authConfiguration.emailCodes')"
        :description="$t('settings.authConfiguration.limitsOnWrongDigitCodes')"
      >
        <details class="group rounded-md border border-border">
          <summary class="cursor-pointer px-3 py-2 text-sm font-medium focus-visible:outline-2 focus-visible:outline-primary">
            {{ $t('settings.authConfiguration.advancedGuessingLimits') }}
          </summary>
          <div class="grid gap-4 border-t border-border p-3 sm:grid-cols-2">
            <BaseInput
              v-model="numbers.email_code_max_attempts"
              :label="$t('settings.authConfiguration.wrongGuessesPerCode')"
              type="number"
              :hint="$t('settings.authConfiguration.theCodeThenStopsWorking')"
              :error="save.error.value?.fieldError('email_code_max_attempts')"
            />
            <BaseInput
              v-model="numbers.email_code_max_failures_per_email"
              :label="$t('settings.authConfiguration.wrongCodesPerAddress')"
              type="number"
              :hint="$t('settings.authConfiguration.withinTheWindowAcrossEvery')"
              :error="save.error.value?.fieldError('email_code_max_failures_per_email')"
            />
            <BaseInput
              v-model="numbers.email_code_max_failures_per_code"
              :label="$t('settings.authConfiguration.triesOfTheSameCode')"
              type="number"
              :hint="$t('settings.authConfiguration.withinTheWindowAcrossAll')"
              :error="save.error.value?.fieldError('email_code_max_failures_per_code')"
            />
            <BaseInput
              v-model="numbers.email_code_failure_window_seconds"
              :label="$t('settings.authConfiguration.windowSeconds')"
              type="number"
              :hint="durationHint('email_code_failure_window_seconds', $t('settings.authConfiguration.ranges.seconds300To86400'))"
              :error="save.error.value?.fieldError('email_code_failure_window_seconds')"
            />
          </div>
        </details>
      </BaseCard>

      <BaseCard :title="$t('settings.authConfiguration.passkeys')">
        <BaseSelect
          v-model="passkeys"
          :label="$t('settings.authConfiguration.passkeys')"
          :options="passkeysOptions"
          :hint="
            forProject ? $t('settings.authConfiguration.passkeysProjectHint') : $t('settings.authConfiguration.passkeysConsoleHint')
          "
          :error="save.error.value?.fieldError('passkeys')"
        />
        <BaseAlert v-if="passkeysWarning" variant="warning">{{ passkeysWarning }}</BaseAlert>
              <BaseCheckbox
          v-model="flags.passwordless_after_passkey"
          :label="$t('settings.authConfiguration.noPasswordsOnceAUser')"
          :disabled="passkeys === 'off'"
          :hint="
            passkeys === 'off' ? $t('settings.authConfiguration.passkeysOffFirst') : $t('settings.authConfiguration.passwordlessHint')
          "
        />
        <p v-if="save.error.value?.fieldError('passwordless_after_passkey')" class="text-xs font-medium text-danger">
          {{ $t('base.field.error', { message: save.error.value?.fieldError('passwordless_after_passkey') }) }}
        </p>
      </BaseCard>
    </template>

    <BaseCard v-if="shown('mfa')" :title="$t('settings.authConfiguration.multiFactorAuthenticationPolicy')">
      <BaseSelect
        v-model="mfaRequirement"
        :label="$t('settings.authConfiguration.requirement')"
        :options="mfaRequirementOptions"
        :hint="$t('settings.authConfiguration.whenRequiredUsersWithoutAn')"
        :error="save.error.value?.fieldError('mfa_requirement')"
      />
      <BaseSelect
        v-model="otpMethod"
        :label="$t('settings.authConfiguration.method')"
        :options="otpMethodOptions"
        :hint="$t('settings.authConfiguration.everyoneSetsUpThisMethod')"
        :error="save.error.value?.fieldError('otp_method')"
      />
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput
          v-model="numbers.otp_digits"
          :label="$t('settings.authConfiguration.codeLengthDigits')"
          type="number"
          :hint="$t('settings.authConfiguration.appliesToNewSetupsOnly')"
          :error="save.error.value?.fieldError('otp_digits')"
        />
        <BaseInput
          v-model="numbers.otp_step_seconds"
          :label="$t('settings.authConfiguration.codeLifetimeSeconds')"
          type="number"
          :hint="durationHint('otp_step_seconds', $t('settings.authConfiguration.ranges.seconds30To900'), $t('settings.authConfiguration.notes.timeBasedOnly'))"
          :error="save.error.value?.fieldError('otp_step_seconds')"
        />
      </div>
      <BaseAlert v-if="unusualOtpFormat" variant="warning" :title="$t('settings.authConfiguration.checkYourUsersApps')">
        {{ $t('settings.authConfiguration.googleAuthenticatorAndMicrosoftAuthenticator') }}
      </BaseAlert>
      <BaseInput
        v-model="numbers.mfa_max_failed_attempts"
        :label="$t('settings.authConfiguration.wrongCodesBeforeTheUser')"
        type="number"
        :hint="$t('settings.authConfiguration.consecutiveWrongAuthenticatorOrRecovery')"
        :error="save.error.value?.fieldError('mfa_max_failed_attempts')"
      />
      <details class="rounded-md border border-border">
        <summary class="cursor-pointer px-3 py-2 text-sm font-medium focus-visible:outline-2 focus-visible:outline-primary">
          {{ $t('settings.authConfiguration.advancedCodeTolerance') }}
        </summary>
        <div class="grid gap-4 border-t border-border p-3 sm:grid-cols-2">
          <BaseInput
            v-model="numbers.otp_drift_steps"
            :label="$t('settings.authConfiguration.clockDriftAllowedSteps')"
            type="number"
            :hint="$t('settings.authConfiguration.codesEitherSideOfThe')"
            :error="save.error.value?.fieldError('otp_drift_steps')"
          />
          <BaseInput
            v-model="numbers.otp_hotp_look_ahead"
            :label="$t('settings.authConfiguration.hardwareTokenLookAhead')"
            type="number"
            :hint="$t('settings.authConfiguration.codesAheadForTokensPressed')"
            :error="save.error.value?.fieldError('otp_hotp_look_ahead')"
          />
        </div>
      </details>
    </BaseCard>

    <template v-if="shown('policies')">
      <BaseCard :title="$t('settings.authConfiguration.passwordRules')">
        <div class="grid gap-4 sm:grid-cols-2">
          <BaseInput
            v-model="numbers.password_min_length"
            :label="$t('settings.authConfiguration.minimumLength')"
            type="number"
            :hint="$t('settings.authConfiguration.characters')"
            :error="save.error.value?.fieldError('password_min_length')"
          />
          <BaseInput
            v-model="numbers.password_max_age_seconds"
            :label="$t('settings.authConfiguration.maximumAgeSeconds')"
            type="number"
            :hint="durationHint('password_max_age_seconds', $t('settings.authConfiguration.ranges.days1To365'), $t('settings.authConfiguration.notes.neverExpire'))"
            :error="save.error.value?.fieldError('password_max_age_seconds')"
          />
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <BaseCheckbox v-model="flags.password_require_uppercase" :label="$t('settings.authConfiguration.requireAnUppercaseLetter')" />
          <BaseCheckbox v-model="flags.password_require_lowercase" :label="$t('settings.authConfiguration.requireALowercaseLetter')" />
          <BaseCheckbox v-model="flags.password_require_number" :label="$t('settings.authConfiguration.requireANumber')" />
          <BaseCheckbox v-model="flags.password_require_symbol" :label="$t('settings.authConfiguration.requireASymbol')" />
        </div>
      </BaseCard>

      <BaseCard :title="$t('settings.authConfiguration.lockout')" :description="$t('settings.authConfiguration.locksAnEmailAddressAfter')">
        <div class="grid gap-4 sm:grid-cols-3">
          <BaseInput
            v-model="numbers.lockout_threshold"
            :label="$t('settings.authConfiguration.failedAttempts')"
            type="number"
            :hint="$t('settings.authConfiguration.lockoutThresholdRange')"
            :error="save.error.value?.fieldError('lockout_threshold')"
          />
          <BaseInput
            v-model="numbers.lockout_window_seconds"
            :label="$t('settings.authConfiguration.withinSeconds')"
            type="number"
            :hint="durationHint('lockout_window_seconds', $t('settings.authConfiguration.ranges.seconds60To86400'))"
            :error="save.error.value?.fieldError('lockout_window_seconds')"
          />
          <BaseInput
            v-model="numbers.lockout_duration_seconds"
            :label="$t('settings.authConfiguration.lockForSeconds')"
            type="number"
            :hint="durationHint('lockout_duration_seconds', $t('settings.authConfiguration.ranges.seconds60To86400'))"
            :error="save.error.value?.fieldError('lockout_duration_seconds')"
          />
        </div>
      </BaseCard>

      <BaseCard :title="$t('settings.authConfiguration.signInAlerts')">
        <BaseCheckbox
          v-model="flags.notify_new_devices"
          :label="$t('settings.authConfiguration.emailUsersAboutSignIns')"
          :hint="$t('settings.authConfiguration.sentWhenSomeoneSignsIn')"
        />
      </BaseCard>
    </template>

    <BaseCard v-if="shown('tokens')" :title="$t('settings.authConfiguration.sessionsAndTokens')">
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput
          v-model="numbers.access_token_ttl_seconds"
          :label="$t('settings.authConfiguration.accessTokenLifetimeSeconds')"
          type="number"
          :hint="durationHint('access_token_ttl_seconds', $t('settings.authConfiguration.ranges.seconds300To3600'))"
          :error="save.error.value?.fieldError('access_token_ttl_seconds')"
        />
        <BaseInput
          v-model="numbers.refresh_token_ttl_seconds"
          :label="$t('settings.authConfiguration.sessionLifetimeSeconds')"
          type="number"
          :hint="durationHint('refresh_token_ttl_seconds', $t('settings.authConfiguration.ranges.days1To365'), $t('settings.authConfiguration.notes.refreshTokensStop'))"
          :error="save.error.value?.fieldError('refresh_token_ttl_seconds')"
        />
        <BaseInput
          v-model="numbers.session_idle_timeout_seconds"
          :label="$t('settings.authConfiguration.idleTimeoutSeconds')"
          type="number"
          :hint="durationHint('session_idle_timeout_seconds', $t('settings.authConfiguration.ranges.minutes5ToDays30'), $t('settings.authConfiguration.notes.noIdleTimeout'))"
          :error="save.error.value?.fieldError('session_idle_timeout_seconds')"
        />
        <BaseInput
          v-if="forProject"
          v-model="numbers.sso_session_ttl_seconds"
          :label="$t('settings.authConfiguration.hostedLoginSessionSeconds')"
          type="number"
          :hint="durationHint('sso_session_ttl_seconds', $t('settings.authConfiguration.ranges.minutes5ToDays30'), $t('settings.authConfiguration.notes.hostedSessionLength'))"
          :error="save.error.value?.fieldError('sso_session_ttl_seconds')"
        />
      </div>
      <p class="text-xs text-text-muted">
        {{ $t('settings.authConfiguration.refreshTokensAlwaysRotateOn') }}
      </p>
    </BaseCard>

    <BaseCard v-if="shown('tokens') && forProject" :title="$t('settings.authConfiguration.appClients')" :description="$t('settings.authConfiguration.limitsForApplicationsCallingThe')">
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput
          v-model="numbers.token_requests_per_minute"
          :label="$t('settings.authConfiguration.tokenRequestsPerClientPer')"
          type="number"
          :hint="$t('settings.authConfiguration.requestsOverTheLimitGet')"
          :error="save.error.value?.fieldError('token_requests_per_minute')"
        />
        <BaseInput
          v-model="numbers.client_secret_rotation_overlap_seconds"
          :label="$t('settings.authConfiguration.oldSecretsKeepWorkingAfter')"
          type="number"
          :hint="durationHint('client_secret_rotation_overlap_seconds', $t('settings.authConfiguration.ranges.days0To30'), $t('settings.authConfiguration.notes.zeroStopsAtOnce'))"
          :error="save.error.value?.fieldError('client_secret_rotation_overlap_seconds')"
        />
      </div>
    </BaseCard>

    <BaseCard v-if="shown('signing')" :title="$t('settings.authConfiguration.tokenSigning')">
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseSelect
          v-model="signingAlgorithm"
          :label="$t('settings.authConfiguration.signingAlgorithm')"
          :options="signingAlgorithmOptions"
          :hint="$t('settings.authConfiguration.changingItCreatesANew')"
          :error="save.error.value?.fieldError('signing_algorithm')"
        />
        <BaseInput
          v-model="numbers.signing_key_rotation_seconds"
          :label="$t('settings.authConfiguration.rotateKeysEverySeconds')"
          type="number"
          :hint="durationHint('signing_key_rotation_seconds', $t('settings.authConfiguration.ranges.days30To365'))"
          :error="save.error.value?.fieldError('signing_key_rotation_seconds')"
        />
      </div>
    </BaseCard>

    </fieldset>
    <div v-if="!readonly" class="flex flex-wrap items-center gap-2">
      <BaseButton type="submit" :label="$t('settings.authConfiguration.saveChanges')" :loading="save.loading.value" :disabled="!dirty" />
      <BaseButton v-if="dirty" :label="$t('settings.authConfiguration.discardChanges')" variant="secondary" @click="discard" />
      <span v-if="dirty" class="text-sm text-text-muted" role="status">{{ $t('settings.authConfiguration.unsavedChanges') }}</span>
    </div>
  </form>
</template>
