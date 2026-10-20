<script setup lang="ts">
import { ref } from 'vue'
import { storeToRefs } from 'pinia'

import RecoveryCodesList from '@/components/auth/RecoveryCodesList.vue'
import TotpSetup from '@/components/auth/TotpSetup.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { meService } from '@/services/account'
import { useSessionStore } from '@/stores/session'
import type { MfaEnrollment } from '@/types/api'

const session = useSessionStore()
const { account, me } = storeToRefs(session)

const name = ref(me.value?.name ?? '')
const profileSaved = ref(false)

const currentPassword = ref('')
const newPassword = ref('')
const passwordChanged = ref(false)

const newEmail = ref('')
const emailPassword = ref('')
const emailOtp = ref('')
const emailRequested = ref<string | null>(null)

const enrollment = ref<MfaEnrollment | null>(null)
const enrollmentCode = ref('')
const recoveryCodes = ref<string[]>([])
const disablePassword = ref('')
const mfaCode = ref('')

const saveProfile = useAsyncAction(async () => {
  if (!account.value) return
  profileSaved.value = false
  me.value = await meService.update(account.value.uid, name.value)
  profileSaved.value = true
})

const changePassword = useAsyncAction(async () => {
  if (!account.value) return
  passwordChanged.value = false
  await meService.changePassword(account.value.uid, currentPassword.value, newPassword.value)
  currentPassword.value = ''
  newPassword.value = ''
  passwordChanged.value = true
})

const requestEmailChange = useAsyncAction(async () => {
  if (!account.value) return
  emailRequested.value = null
  await meService.requestEmailChange(account.value.uid, newEmail.value, emailPassword.value, emailOtp.value || undefined)
  emailRequested.value = newEmail.value
  newEmail.value = ''
  emailPassword.value = ''
  emailOtp.value = ''
})

const startTotp = useAsyncAction(async () => {
  if (!account.value) return
  recoveryCodes.value = []
  enrollment.value = await meService.startTotp(account.value.uid)
})

const confirmTotp = useAsyncAction(async () => {
  if (!account.value) return
  const result = await meService.confirmTotp(account.value.uid, enrollmentCode.value)
  recoveryCodes.value = result.recovery_codes
  enrollment.value = null
  enrollmentCode.value = ''
  await session.loadMe()
})

const disableTotp = useAsyncAction(async () => {
  if (!account.value) return
  await meService.disableTotp(account.value.uid, disablePassword.value, mfaCode.value)
  disablePassword.value = ''
  mfaCode.value = ''
  recoveryCodes.value = []
  await session.loadMe()
})

const regenerateCodes = useAsyncAction(async () => {
  if (!account.value) return
  const result = await meService.regenerateRecoveryCodes(account.value.uid, mfaCode.value)
  recoveryCodes.value = result.recovery_codes
  mfaCode.value = ''
})
</script>

<template>
  <PageHeader title="My security" description="Your profile, password, email address and multi-factor authentication." />

  <BaseCard title="Profile">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="saveProfile.run()">
      <BaseAlert v-if="profileSaved" variant="success">Profile saved.</BaseAlert>
      <BaseInput v-model="name" label="Name" autocomplete="name" required :error="saveProfile.error.value?.fieldError('name')" />
      <BaseButton type="submit" label="Save" :loading="saveProfile.loading.value" class="self-start" />
    </form>
  </BaseCard>

  <BaseCard title="Password" description="Changing your password signs you out of every other session.">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="changePassword.run()">
      <BaseAlert v-if="passwordChanged" variant="success">Password changed. Your other sessions have been signed out.</BaseAlert>
      <input type="text" :value="me?.email" autocomplete="username" class="sr-only" tabindex="-1" aria-hidden="true" readonly />
      <BaseInput
        v-model="currentPassword"
        label="Current password"
        type="password"
        autocomplete="current-password"
        required
        :error="changePassword.error.value?.fieldError('current_password')"
      />
      <BaseInput
        v-model="newPassword"
        label="New password"
        type="password"
        autocomplete="new-password"
        required
        :error="changePassword.error.value?.fieldError('new_password')"
      />
      <BaseButton type="submit" label="Change password" :loading="changePassword.loading.value" class="self-start" />
    </form>
  </BaseCard>

  <BaseCard title="Email address" :description="`You sign in with ${me?.email ?? 'your email'}. It changes only after you confirm the new address.`">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="requestEmailChange.run()">
      <BaseAlert v-if="emailRequested" variant="success" title="Check your inbox">
        If {{ emailRequested }} can be used, we've sent a confirmation link to it. The link expires in 1 hour.
      </BaseAlert>
      <BaseAlert
        v-if="requestEmailChange.error.value && requestEmailChange.error.value.details.length === 0"
        variant="danger"
      >
        {{ requestEmailChange.error.value.message }}
      </BaseAlert>
      <BaseInput
        v-model="newEmail"
        label="New email"
        type="email"
        autocomplete="email"
        required
        :error="requestEmailChange.error.value?.fieldError('new_email')"
      />
      <BaseInput
        v-model="emailPassword"
        label="Current password"
        type="password"
        autocomplete="current-password"
        required
        :error="requestEmailChange.error.value?.fieldError('current_password')"
      />
      <BaseInput
        v-if="me?.mfa_enabled"
        v-model="emailOtp"
        label="Verification code"
        autocomplete="one-time-code"
        inputmode="numeric"
        required
      />
      <BaseButton type="submit" label="Change email" :loading="requestEmailChange.loading.value" class="self-start" />
    </form>
  </BaseCard>

  <BaseCard
    title="Multi-factor authentication"
    :description="me?.mfa_enabled ? 'On. You enter a code from your authenticator app when you sign in.' : 'Off. Add an authenticator app to protect your account.'"
  >
    <RecoveryCodesList v-if="recoveryCodes.length > 0" :codes="recoveryCodes" />

    <template v-if="!me?.mfa_enabled">
      <BaseAlert v-if="startTotp.error.value" variant="danger">{{ startTotp.error.value.message }}</BaseAlert>
      <BaseButton
        v-if="!enrollment"
        label="Set up authenticator app"
        :loading="startTotp.loading.value"
        class="self-start"
        @click="startTotp.run()"
      />

      <form v-else class="flex flex-col gap-4" novalidate @submit.prevent="confirmTotp.run()">
        <TotpSetup :enrollment="enrollment" />
        <BaseAlert v-if="confirmTotp.error.value" variant="danger">{{ confirmTotp.error.value.message }}</BaseAlert>
        <BaseInput v-model="enrollmentCode" label="Verification code" autocomplete="one-time-code" inputmode="numeric" required />
        <div class="flex gap-2">
          <BaseButton type="submit" label="Turn on MFA" :loading="confirmTotp.loading.value" />
          <BaseButton label="Cancel" variant="secondary" @click="enrollment = null" />
        </div>
      </form>
    </template>

    <form v-else class="flex flex-col gap-4" novalidate @submit.prevent="regenerateCodes.run()">
      <BaseAlert v-if="regenerateCodes.error.value" variant="danger">{{ regenerateCodes.error.value.message }}</BaseAlert>
      <BaseAlert v-if="disableTotp.error.value && disableTotp.error.value.details.length === 0" variant="danger">
        {{ disableTotp.error.value.message }}
      </BaseAlert>
      <BaseInput
        v-model="mfaCode"
        label="Verification code"
        hint="Needed to get new recovery codes or turn MFA off."
        autocomplete="one-time-code"
        inputmode="numeric"
        required
      />
      <BaseInput
        v-model="disablePassword"
        label="Current password"
        type="password"
        autocomplete="current-password"
        hint="Only needed to turn MFA off."
        :error="disableTotp.error.value?.fieldError('current_password')"
      />
      <div class="flex flex-wrap gap-2">
        <BaseButton type="submit" label="Get new recovery codes" variant="secondary" :loading="regenerateCodes.loading.value" />
        <BaseButton label="Turn off MFA" variant="danger" :loading="disableTotp.loading.value" @click="disableTotp.run()" />
      </div>
    </form>
  </BaseCard>
</template>
