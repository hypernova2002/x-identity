<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { storeToRefs } from 'pinia'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { accountService } from '@/services/account'
import { useSessionStore } from '@/stores/session'
import type { AuthConfiguration, MfaRequirement, SigningAlgorithm } from '@/types/api'
import { mfaRequirementOptions, signingAlgorithmOptions } from '@/utils/options'

type NumberField =
  | 'password_min_length'
  | 'password_max_age_days'
  | 'lockout_threshold'
  | 'lockout_window_minutes'
  | 'lockout_duration_minutes'
  | 'access_token_ttl_minutes'
  | 'refresh_token_ttl_days'
  | 'session_idle_timeout_minutes'
  | 'signing_key_rotation_days'

const OPTIONAL_FIELDS: NumberField[] = ['password_max_age_days', 'session_idle_timeout_minutes']

const { account } = storeToRefs(useSessionStore())

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
  password_max_age_days: '',
  lockout_threshold: '',
  lockout_window_minutes: '',
  lockout_duration_minutes: '',
  access_token_ttl_minutes: '',
  refresh_token_ttl_days: '',
  session_idle_timeout_minutes: '',
  signing_key_rotation_days: '',
})
const saved = ref(false)

function apply(configuration: AuthConfiguration) {
  mfaRequirement.value = configuration.mfa_requirement
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

function numberValue(field: NumberField): number | null {
  const raw = numbers.value[field].trim()
  if (raw === '' && OPTIONAL_FIELDS.includes(field)) return null
  return Number(raw)
}

const load = useAsyncAction(async () => {
  if (!account.value) return
  apply(await accountService.getAuthConfiguration(account.value.uid))
})

const save = useAsyncAction(async () => {
  if (!account.value) return
  saved.value = false

  const changes: Partial<AuthConfiguration> = {
    mfa_requirement: mfaRequirement.value,
    signing_algorithm: signingAlgorithm.value,
    ...flags.value,
  }
  for (const field of Object.keys(numbers.value) as NumberField[]) {
    Object.assign(changes, { [field]: numberValue(field) })
  }

  apply(await accountService.updateAuthConfiguration(account.value.uid, changes))
  saved.value = true
})

onMounted(() => load.run())
</script>

<template>
  <PageHeader
    title="Authentication"
    description="How people sign in to this account's console. Changes apply from each user's next sign-in or token refresh."
  />

  <p v-if="load.loading.value" class="text-sm text-text-muted" role="status">Loading settings…</p>
  <BaseAlert v-else-if="load.error.value" variant="danger">We couldn't load the settings. {{ load.error.value.message }}</BaseAlert>

  <form v-else class="flex flex-col gap-6" novalidate @submit.prevent="save.run()">
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
    </BaseCard>

    <BaseCard title="Email verification">
      <BaseCheckbox
        v-model="flags.require_email_verification"
        label="Require a verified email before signing in"
        hint="Off by default while the console is being tested."
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
          v-model="numbers.password_max_age_days"
          label="Maximum age (days)"
          type="number"
          hint="1–365. Leave empty to never expire passwords."
          :error="save.error.value?.fieldError('password_max_age_days')"
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
          v-model="numbers.lockout_window_minutes"
          label="Within (minutes)"
          type="number"
          hint="1–1440."
          :error="save.error.value?.fieldError('lockout_window_minutes')"
        />
        <BaseInput
          v-model="numbers.lockout_duration_minutes"
          label="Lock for (minutes)"
          type="number"
          hint="1–1440."
          :error="save.error.value?.fieldError('lockout_duration_minutes')"
        />
      </div>
    </BaseCard>

    <BaseCard title="Sessions and tokens">
      <div class="grid gap-4 sm:grid-cols-3">
        <BaseInput
          v-model="numbers.access_token_ttl_minutes"
          label="Access token lifetime (minutes)"
          type="number"
          hint="5–60."
          :error="save.error.value?.fieldError('access_token_ttl_minutes')"
        />
        <BaseInput
          v-model="numbers.refresh_token_ttl_days"
          label="Session lifetime (days)"
          type="number"
          hint="1–365. Users sign in again after this."
          :error="save.error.value?.fieldError('refresh_token_ttl_days')"
        />
        <BaseInput
          v-model="numbers.session_idle_timeout_minutes"
          label="Idle timeout (minutes)"
          type="number"
          hint="5–43200. Leave empty for no idle timeout."
          :error="save.error.value?.fieldError('session_idle_timeout_minutes')"
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
          v-model="numbers.signing_key_rotation_days"
          label="Rotate keys every (days)"
          type="number"
          hint="30–365."
          :error="save.error.value?.fieldError('signing_key_rotation_days')"
        />
      </div>
    </BaseCard>

    <BaseButton type="submit" label="Save settings" :loading="save.loading.value" class="self-start" />
  </form>
</template>
