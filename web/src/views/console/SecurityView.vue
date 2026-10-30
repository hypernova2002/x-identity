<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import RecoveryCodesList from '@/components/auth/RecoveryCodesList.vue'
import OtpSetup from '@/components/auth/OtpSetup.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import PasskeysCard from '@/components/security/PasskeysCard.vue'
import DeviceSessionTable from '@/components/sessions/DeviceSessionTable.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { meService } from '@/services/account'
import type { ListParams } from '@/services/list'
import { useSessionStore } from '@/stores/session'
import type { DeviceSession, MfaEnrollment } from '@/types/api'
import type { PasskeyRegistrationJSON } from '@/utils/webauthn'

const router = useRouter()
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

const passkeyApi = {
  list: () => meService.listPasskeys(account.value!.uid),
  options: () => meService.passkeyOptions(account.value!.uid),
  add: (registrationId: string, credential: PasskeyRegistrationJSON) => meService.addPasskey(account.value!.uid, registrationId, credential),
  rename: (passkeyUid: string, name: string) => meService.renamePasskey(account.value!.uid, passkeyUid, name),
  remove: (passkeyUid: string) => meService.removePasskey(account.value!.uid, passkeyUid),
}

/** Adding a passkey needs a recent sign-in: sign in again, then come back here. */
async function signInAgain() {
  const slug = account.value?.slug
  await session.signOut()
  await router.push({ name: 'sign-in', params: { slug }, query: { redirect: '/console/security' } })
}

const fetchSessions = (params: ListParams) => meService.listSessions(account.value!.uid, params)
const signOutSession = (deviceSession: DeviceSession) => meService.signOutSession(account.value!.uid, deviceSession.uid)
const signOutOtherSessions = () => meService.signOutOtherSessions(account.value!.uid)

const saveProfile = useAsyncAction(async () => {
  if (!account.value) return
  profileSaved.value = false
  me.value = await meService.update(account.value.uid, { name: name.value })
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

const startOtp = useAsyncAction(async () => {
  if (!account.value) return
  recoveryCodes.value = []
  enrollment.value = await meService.startOtp(account.value.uid)
})

const confirmOtp = useAsyncAction(async () => {
  if (!account.value) return
  const result = await meService.confirmOtp(account.value.uid, enrollmentCode.value)
  recoveryCodes.value = result.recovery_codes
  enrollment.value = null
  enrollmentCode.value = ''
  await session.loadMe()
})

const disableOtp = useAsyncAction(async () => {
  if (!account.value) return
  await meService.disableOtp(account.value.uid, disablePassword.value, mfaCode.value)
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
  <PageHeader :title="$t('console.security.title')" :description="$t('console.security.description')" />

  <BaseCard :title="$t('console.security.profile')">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="saveProfile.run()">
      <BaseAlert v-if="profileSaved" variant="success">{{ $t('console.security.profileSaved') }}</BaseAlert>
      <BaseInput v-model="name" :label="$t('console.security.name')" autocomplete="name" required :error="saveProfile.error.value?.fieldError('name')" />
      <BaseButton type="submit" :label="$t('common.actions.save')" :loading="saveProfile.loading.value" class="self-start" />
    </form>
  </BaseCard>

  <BaseCard :title="$t('console.security.password')" :description="$t('console.security.passwordDescription')">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="changePassword.run()">
      <BaseAlert v-if="passwordChanged" variant="success">{{ $t('console.security.passwordChanged') }}</BaseAlert>
      <input type="text" :value="me?.email" autocomplete="username" class="sr-only" tabindex="-1" aria-hidden="true" readonly />
      <BaseInput
        v-model="currentPassword"
        :label="$t('console.security.currentPassword')"
        type="password"
        autocomplete="current-password"
        required
        :error="changePassword.error.value?.fieldError('current_password')"
      />
      <BaseInput
        v-model="newPassword"
        :label="$t('console.security.newPassword')"
        type="password"
        autocomplete="new-password"
        required
        :error="changePassword.error.value?.fieldError('new_password')"
      />
      <BaseButton type="submit" :label="$t('console.security.changePassword')" :loading="changePassword.loading.value" class="self-start" />
    </form>
  </BaseCard>

  <BaseCard :title="$t('console.security.email')" :description="$t('console.security.emailDescription', { email: me?.email ?? $t('console.security.yourEmail') })">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="requestEmailChange.run()">
      <BaseAlert v-if="emailRequested" variant="success" :title="$t('console.security.emailSentTitle')">
        {{ $t('console.security.emailSent', { email: emailRequested }) }}
      </BaseAlert>
      <BaseAlert
        v-if="requestEmailChange.error.value && requestEmailChange.error.value.details.length === 0"
        variant="danger"
      >
        {{ requestEmailChange.error.value.message }}
      </BaseAlert>
      <BaseInput
        v-model="newEmail"
        :label="$t('console.security.newEmail')"
        type="email"
        autocomplete="email"
        required
        :error="requestEmailChange.error.value?.fieldError('new_email')"
      />
      <BaseInput
        v-model="emailPassword"
        :label="$t('console.security.currentPassword')"
        type="password"
        autocomplete="current-password"
        required
        :error="requestEmailChange.error.value?.fieldError('current_password')"
      />
      <BaseInput
        v-if="me?.mfa_enabled"
        v-model="emailOtp"
        :label="$t('console.security.verificationCode')"
        autocomplete="one-time-code"
        inputmode="numeric"
        required
      />
      <BaseButton type="submit" :label="$t('console.security.changeEmail')" :loading="requestEmailChange.loading.value" class="self-start" />
    </form>
  </BaseCard>

  <BaseCard
    :title="$t('console.security.mfa')"
    :description="me?.mfa_enabled ? $t('console.security.mfaOn') : $t('console.security.mfaOff')"
  >
    <RecoveryCodesList v-if="recoveryCodes.length > 0" :codes="recoveryCodes" />

    <template v-if="!me?.mfa_enabled">
      <BaseAlert v-if="startOtp.error.value" variant="danger">{{ startOtp.error.value.message }}</BaseAlert>
      <BaseButton
        v-if="!enrollment"
        :label="$t('console.security.setUpMfa')"
        :loading="startOtp.loading.value"
        class="self-start"
        @click="startOtp.run()"
      />

      <form v-else class="flex flex-col gap-4" novalidate @submit.prevent="confirmOtp.run()">
        <OtpSetup :enrollment="enrollment" />
        <BaseAlert v-if="confirmOtp.error.value" variant="danger">{{ confirmOtp.error.value.message }}</BaseAlert>
        <BaseInput v-model="enrollmentCode" :label="$t('console.security.verificationCode')" autocomplete="one-time-code" inputmode="numeric" required />
        <div class="flex gap-2">
          <BaseButton type="submit" :label="$t('console.security.turnOnMfa')" :loading="confirmOtp.loading.value" />
          <BaseButton :label="$t('common.actions.cancel')" variant="secondary" @click="enrollment = null" />
        </div>
      </form>
    </template>

    <form v-else class="flex flex-col gap-4" novalidate @submit.prevent="regenerateCodes.run()">
      <BaseAlert v-if="regenerateCodes.error.value" variant="danger">{{ regenerateCodes.error.value.message }}</BaseAlert>
      <BaseAlert v-if="disableOtp.error.value && disableOtp.error.value.details.length === 0" variant="danger">
        {{ disableOtp.error.value.message }}
      </BaseAlert>
      <BaseInput
        v-model="mfaCode"
        :label="$t('console.security.verificationCode')"
        :hint="$t('console.security.codeHint')"
        autocomplete="one-time-code"
        inputmode="numeric"
        required
      />
      <BaseInput
        v-model="disablePassword"
        :label="$t('console.security.currentPassword')"
        type="password"
        autocomplete="current-password"
        :hint="$t('console.security.passwordHint')"
        :error="disableOtp.error.value?.fieldError('current_password')"
      />
      <div class="flex flex-wrap gap-2">
        <BaseButton type="submit" :label="$t('console.security.newCodes')" variant="secondary" :loading="regenerateCodes.loading.value" />
        <BaseButton :label="$t('console.security.turnOffMfa')" variant="danger" :loading="disableOtp.loading.value" @click="disableOtp.run()" />
      </div>
    </form>
  </BaseCard>

  <PasskeysCard v-if="account" :available="me?.passkeys_available ?? false" v-bind="passkeyApi" @reauthenticate="signInAgain" />

  <BaseCard v-if="account" :title="$t('console.security.devices')" :description="$t('console.security.devicesDescription')">
    <DeviceSessionTable :fetch-page="fetchSessions" :sign-out="signOutSession" :sign-out-others="signOutOtherSessions" />
  </BaseCard>
</template>
