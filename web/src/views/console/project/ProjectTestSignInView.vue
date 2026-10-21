<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'

import OtpSetup from '@/components/auth/OtpSetup.vue'
import RecoveryCodesList from '@/components/auth/RecoveryCodesList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { SelectOption } from '@/components/base/types'
import DecodedToken from '@/components/project/DecodedToken.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { useTestSignIn } from '@/composables/useTestSignIn'
import { projectAdminService } from '@/services/project'
import type { AppClient } from '@/types/api'

const { accountUid, project } = useProjectContext()
const flow = useTestSignIn()
const { challenge, enrollment, tokens, recoveryCodes, refreshedAt, signedOut } = flow

const clients = ref<AppClient[]>([])
const clientUid = ref('')
const clientSecret = ref('')
const email = ref('')
const password = ref('')
const code = ref('')
const newPassword = ref('')

const clientOptions = computed<SelectOption[]>(() =>
  clients.value.map((client) => ({ label: `${client.name} (${client.client_type})`, value: client.uid })),
)
const selectedClient = computed(() => clients.value.find((client) => client.uid === clientUid.value))

const challengeTitle = computed(() => `Challenge: ${challenge.value?.challenge ?? ''}`)

watch(challenge, () => {
  code.value = ''
  newPassword.value = ''
})

const loadClients = useAsyncAction(async () => {
  if (!project.value) return
  const { items } = await projectAdminService.listAppClients(accountUid.value, project.value.uid)
  clients.value = items.filter((client) => client.enabled)
  clientUid.value = clients.value[0]?.uid ?? ''
})

function signIn() {
  if (!project.value || !selectedClient.value) return

  const secret = selectedClient.value.client_type === 'confidential' ? clientSecret.value.trim() : ''
  flow.signIn.run(
    { accountUid: accountUid.value, projectUid: project.value.uid },
    { client_id: selectedClient.value.uid, ...(secret ? { client_secret: secret } : {}) },
    email.value,
    password.value,
  )
}

function startOver() {
  flow.reset()
  password.value = ''
  flow.signIn.error.value = null
  flow.answer.error.value = null
  flow.refresh.error.value = null
  flow.signOut.error.value = null
}

onMounted(() => loadClients.run())
</script>

<template>
  <BaseAlert variant="info">
    Signs an end user in through the project's public API, the same way your app does. It doesn't affect your console session. The
    console's origin is always allowed, so this doesn't check an app client's allowed origins.
  </BaseAlert>

  <BaseAlert v-if="loadClients.error.value" variant="danger">
    We couldn't load the app clients. {{ loadClients.error.value.message }}
  </BaseAlert>
  <p v-else-if="loadClients.loading.value" class="text-sm text-text-muted" role="status">Loading app clients…</p>

  <BaseCard v-else-if="clients.length === 0" title="No app clients" description="End users sign in through an enabled app client.">
    <RouterLink :to="{ name: 'project-app-clients' }" class="self-start text-sm font-medium text-primary underline hover:text-primary-hover">
      Create an app client
    </RouterLink>
  </BaseCard>

  <template v-else>
    <BaseCard v-if="!challenge && !tokens" title="Sign in as an end user">
      <form class="flex flex-col gap-4" novalidate @submit.prevent="signIn">
        <BaseAlert v-if="flow.signIn.error.value" variant="danger">
          {{ flow.signIn.error.value.message }}
          <code class="font-mono text-xs">{{ flow.signIn.error.value.code }}</code>
        </BaseAlert>

        <BaseSelect v-model="clientUid" label="App client" :options="clientOptions" />
        <BaseInput
          v-if="selectedClient?.client_type === 'confidential'"
          v-model="clientSecret"
          label="Client secret"
          type="password"
          autocomplete="off"
          hint="Confidential clients must send their secret."
          :error="flow.signIn.error.value?.fieldError('client_secret')"
        />
        <BaseInput
          v-model="email"
          label="End user's email"
          type="email"
          autocomplete="off"
          required
          :error="flow.signIn.error.value?.fieldError('email')"
        />
        <BaseInput
          v-model="password"
          label="Password"
          type="password"
          autocomplete="off"
          required
          :error="flow.signIn.error.value?.fieldError('password')"
        />
        <BaseButton type="submit" label="Sign in" :loading="flow.signIn.loading.value" class="self-start" />
      </form>
    </BaseCard>

    <BaseCard v-else-if="challenge" :title="challengeTitle" description="The API asked for another step before issuing tokens.">
      <form class="flex flex-col gap-4" novalidate @submit.prevent="flow.answer.run({ code, newPassword })">
        <BaseAlert v-if="flow.answer.error.value && flow.answer.error.value.details.length === 0" variant="danger">
          {{ flow.answer.error.value.message }}
          <code class="font-mono text-xs">{{ flow.answer.error.value.code }}</code>
        </BaseAlert>

        <template v-if="challenge.challenge === 'otp'">
          <p class="text-sm text-text-muted">Enter a code from the end user's authenticator app or hardware token, or a recovery code.</p>
          <BaseInput
            v-model="code"
            label="Verification code"
            autocomplete="off"
            required
            :error="flow.answer.error.value?.fieldError('code')"
          />
        </template>

        <template v-else-if="challenge.challenge === 'new_password'">
          <p class="text-sm text-text-muted">The end user's password has expired and must be changed.</p>
          <BaseInput
            v-model="newPassword"
            label="New password"
            type="password"
            autocomplete="off"
            required
            :error="flow.answer.error.value?.fieldError('new_password')"
          />
        </template>

        <template v-else-if="challenge.challenge === 'mfa_setup'">
          <p class="text-sm text-text-muted">The project requires MFA and this end user hasn't set it up yet.</p>
          <OtpSetup v-if="enrollment" :enrollment="enrollment" />
          <BaseInput
            v-model="code"
            label="Verification code"
            autocomplete="off"
            inputmode="numeric"
            required
            :error="flow.answer.error.value?.fieldError('code')"
          />
        </template>

        <div class="flex flex-wrap gap-2">
          <BaseButton
            v-if="flow.answer.error.value?.code !== 'invalid_challenge'"
            type="submit"
            label="Continue"
            :loading="flow.answer.loading.value"
          />
          <BaseButton label="Start over" variant="secondary" @click="startOver" />
        </div>
      </form>
    </BaseCard>

    <template v-else-if="tokens">
      <RecoveryCodesList v-if="recoveryCodes.length > 0" :codes="recoveryCodes" />

      <BaseCard title="Signed in" :description="`Access token expires in ${tokens.expires_in} seconds.`">
        <BaseAlert v-if="signedOut" variant="success">
          Signed out. The refresh token is revoked, so refreshing now should fail. Access tokens stay valid until they expire.
        </BaseAlert>
        <BaseAlert v-else-if="refreshedAt" variant="success">
          Refreshed at {{ refreshedAt.toLocaleTimeString() }}. The previous refresh token is now used up.
        </BaseAlert>
        <BaseAlert v-if="flow.refresh.error.value" variant="danger">
          Refresh failed: {{ flow.refresh.error.value.message }}
          <code class="font-mono text-xs">{{ flow.refresh.error.value.code }}</code>
        </BaseAlert>
        <BaseAlert v-if="flow.signOut.error.value" variant="danger">
          Sign-out failed: {{ flow.signOut.error.value.message }}
          <code class="font-mono text-xs">{{ flow.signOut.error.value.code }}</code>
        </BaseAlert>

        <div class="flex flex-wrap gap-2">
          <BaseButton label="Refresh tokens" variant="secondary" :loading="flow.refresh.loading.value" @click="flow.refresh.run()" />
          <BaseButton
            label="Sign out"
            variant="secondary"
            :disabled="signedOut"
            :loading="flow.signOut.loading.value"
            @click="flow.signOut.run()"
          />
          <BaseButton label="Start over" variant="ghost" @click="startOver" />
        </div>

        <DecodedToken label="Access token" :token="tokens.access_token" />
        <DecodedToken v-if="tokens.id_token" label="ID token" :token="tokens.id_token" />
        <DecodedToken label="Refresh token" :token="tokens.refresh_token" />
      </BaseCard>
    </template>
  </template>
</template>
