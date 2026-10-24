<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import OtpSetup from '@/components/auth/OtpSetup.vue'
import RecoveryCodesList from '@/components/auth/RecoveryCodesList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSearchSelect from '@/components/base/BaseSearchSelect.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { SelectOption } from '@/components/base/types'
import DecodedToken from '@/components/project/DecodedToken.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useOidcCodeFlow } from '@/composables/useOidcCodeFlow'
import { useProjectContext } from '@/composables/useProjectContext'
import { useProjectLookups } from '@/composables/useProjectLookups'
import { useTestSignIn } from '@/composables/useTestSignIn'
import { oidcService } from '@/services/oidc'
import { projectAdminService } from '@/services/project'
import type { AppClient } from '@/types/api'
import { explainSignInError } from '@/utils/signInErrors'

const route = useRoute()
const router = useRouter()
const { accountUid, project } = useProjectContext()
const flow = useTestSignIn()
const hostedLogin = useOidcCodeFlow({ storageKey: 'x-identity:test-hosted-login', scope: 'openid email profile groups offline_access' })
const { challenge, enrollment, tokens, recoveryCodes, refreshedAt, signedOut } = flow

const lookups = useProjectLookups()
const hasClients = ref(false)
const clientUid = ref('')
const selectedClient = ref<AppClient | null>(null)
const clientSecret = ref('')
const email = ref('')
const password = ref('')
const code = ref('')
const newPassword = ref('')


const hostedRedirectUri = computed(() => (project.value ? `${window.location.origin}/console/projects/${project.value.uid}/test-sign-in` : ''))
const hostedLoginReady = computed(
  () => selectedClient.value?.client_type === 'public' && selectedClient.value.redirect_uris.includes(hostedRedirectUri.value),
)

const challengeTitle = computed(() => `Challenge: ${challenge.value?.challenge ?? ''}`)

watch(challenge, () => {
  code.value = ''
  newPassword.value = ''
})

const loadClients = useAsyncAction(async () => {
  if (!project.value) return
  const firstPage = await lookups.searchAppClients('')
  hasClients.value = firstPage.total > 0
  clientUid.value = typeof route.query.client === 'string' ? route.query.client : (firstPage.items[0]?.value ?? '')
})

const loadClient = useAsyncAction(async (uid: string) => {
  selectedClient.value = null
  if (!project.value || !uid) return
  selectedClient.value = await projectAdminService.getAppClient(accountUid.value, project.value.uid, uid)
})

watch(clientUid, (uid) => loadClient.run(uid))

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

function startHostedLogin() {
  if (!project.value || !selectedClient.value) return
  hostedLogin.start.run(project.value.token_issuer, selectedClient.value.uid, hostedRedirectUri.value)
}

function endHostedSession() {
  if (project.value) window.location.assign(oidcService.logoutUrl(project.value.token_issuer))
}

async function finishHostedLogin() {
  const text = (key: string) => (typeof route.query[key] === 'string' ? (route.query[key] as string) : undefined)
  if (!project.value || (!text('code') && !text('error'))) return

  const result = await hostedLogin.complete.run({
    code: text('code'),
    state: text('state'),
    error: text('error'),
    errorDescription: text('error_description'),
  })
  await router.replace({ query: {} })
  if (result) flow.adopt({ accountUid: accountUid.value, projectUid: project.value.uid }, { client_id: result.clientId }, result.tokens)
}

function startOver() {
  flow.reset()
  password.value = ''
  flow.signIn.error.value = null
  flow.answer.error.value = null
  flow.refresh.error.value = null
  flow.signOut.error.value = null
  hostedLogin.complete.error.value = null
}

onMounted(() => {
  loadClients.run()
  finishHostedLogin()
})
</script>

<template>
  <BaseAlert variant="info">
    Signs an end user in through the project's public API, the same way your app does. It doesn't affect your console session. The
    console's origin is always allowed, so this doesn't check an app client's allowed origins. Tokens are shown only on this page
    and kept in memory, never stored.
  </BaseAlert>
  <p v-if="selectedClient" class="text-sm text-text-muted">
    Testing
    <RouterLink :to="{ name: 'project-app-client', params: { projectUid: project?.uid, clientUid: selectedClient.uid } }" class="font-medium text-primary underline">
      {{ selectedClient.name }}</RouterLink
    >. Its sign-ins appear in its Activity tab and the
    <RouterLink :to="{ name: 'project-audit-log', params: { projectUid: project?.uid }, query: { app_client_uid_eq: selectedClient.uid } }" class="font-medium text-primary underline">
      audit log</RouterLink
    >.
  </p>

  <BaseAlert v-if="loadClients.error.value" variant="danger">
    We couldn't load the app clients. {{ loadClients.error.value.message }}
  </BaseAlert>
  <p v-else-if="loadClients.loading.value" class="text-sm text-text-muted" role="status">Loading app clients…</p>

  <BaseCard v-else-if="!hasClients" title="No OpenID Connect or API clients" description="End users sign in through an enabled client.">
    <RouterLink
      :to="{ name: 'project-applications', params: { projectUid: project?.uid } }"
      class="self-start text-sm font-medium text-primary underline hover:text-primary-hover"
    >
      Add an application
    </RouterLink>
  </BaseCard>

  <template v-else>
    <BaseCard v-if="!challenge && !tokens" title="Sign in as an end user">
      <form class="flex flex-col gap-4" novalidate @submit.prevent="signIn">
        <BaseAlert v-if="flow.signIn.error.value" variant="danger">
          {{ flow.signIn.error.value.message }}
          <code class="font-mono text-xs">{{ flow.signIn.error.value.code }}</code>
          <p v-if="flow.signIn.error.value && explainSignInError(flow.signIn.error.value.code)" class="text-sm">{{ explainSignInError(flow.signIn.error.value.code) }}</p>
        </BaseAlert>

        <BaseSearchSelect
          v-model="clientUid"
          label="App client"
          :search="lookups.searchAppClients"
          :resolve-label="lookups.appClientName"
          :see-all="lookups.allApplications.value"
          :error="loadClient.error.value?.message"
        />
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

      <section class="flex flex-col gap-4 border-t border-border pt-4" aria-labelledby="hosted-login-heading">
        <h3 id="hosted-login-heading" class="text-sm font-semibold">Or use hosted login (OpenID Connect)</h3>
        <p class="text-sm text-text-muted">
          Runs the authorization code flow with PKCE, with this page as the app: you sign in on the project's hosted login page and
          come back here with tokens. A hosted login session also signs you in to the project's other apps until you end it.
        </p>
        <BaseAlert v-if="hostedLogin.complete.error.value" variant="danger">
          {{ hostedLogin.complete.error.value.message }}
          <code class="font-mono text-xs">{{ hostedLogin.complete.error.value.code }}</code>
          <p v-if="hostedLogin.complete.error.value && explainSignInError(hostedLogin.complete.error.value.code)" class="text-sm">{{ explainSignInError(hostedLogin.complete.error.value.code) }}</p>
        </BaseAlert>
        <p v-if="hostedLogin.complete.loading.value" class="text-sm text-text-muted" role="status">Finishing hosted sign-in…</p>
        <BaseAlert v-if="selectedClient?.client_type === 'confidential'" variant="info">
          Choose a public app client: this page can't keep a client secret.
        </BaseAlert>
        <BaseAlert v-else-if="!hostedLoginReady" variant="warning" title="Add this page as a redirect URI">
          Add <code class="font-mono text-xs break-all">{{ hostedRedirectUri }}</code> to the redirect URIs of
          <RouterLink
            v-if="selectedClient"
            :to="{ name: 'project-app-client-sign-in', params: { projectUid: project?.uid, clientUid: selectedClient.uid } }"
            class="font-medium text-primary underline hover:text-primary-hover"
          >
            {{ selectedClient.name }}</RouterLink
          >.
        </BaseAlert>
        <div class="flex flex-wrap gap-2">
          <BaseButton
            label="Sign in with hosted login"
            variant="secondary"
            :disabled="!hostedLoginReady"
            :loading="hostedLogin.start.loading.value"
            @click="startHostedLogin"
          />
          <BaseButton label="End hosted login session" variant="ghost" @click="endHostedSession" />
        </div>
      </section>
    </BaseCard>

    <BaseCard v-else-if="challenge" :title="challengeTitle" description="The API asked for another step before issuing tokens.">
      <form class="flex flex-col gap-4" novalidate @submit.prevent="flow.answer.run({ code, newPassword })">
        <BaseAlert v-if="flow.answer.error.value && flow.answer.error.value.details.length === 0" variant="danger">
          {{ flow.answer.error.value.message }}
          <code class="font-mono text-xs">{{ flow.answer.error.value.code }}</code>
          <p v-if="flow.answer.error.value && explainSignInError(flow.answer.error.value.code)" class="text-sm">{{ explainSignInError(flow.answer.error.value.code) }}</p>
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
          <p v-if="flow.refresh.error.value && explainSignInError(flow.refresh.error.value.code)" class="text-sm">{{ explainSignInError(flow.refresh.error.value.code) }}</p>
        </BaseAlert>
        <BaseAlert v-if="flow.signOut.error.value" variant="danger">
          Sign-out failed: {{ flow.signOut.error.value.message }}
          <code class="font-mono text-xs">{{ flow.signOut.error.value.code }}</code>
          <p v-if="flow.signOut.error.value && explainSignInError(flow.signOut.error.value.code)" class="text-sm">{{ explainSignInError(flow.signOut.error.value.code) }}</p>
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
