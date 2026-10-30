<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import OtpSetup from '@/components/auth/OtpSetup.vue'
import RecoveryCodesList from '@/components/auth/RecoveryCodesList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSearchSelect from '@/components/base/BaseSearchSelect.vue'
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
import { currentLocale } from '@/i18n'

const { t } = useI18n()

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

const challengeTitle = computed(() => t('project.projectTestSignIn.challenge', { challenge: challenge.value?.challenge ?? '' }))

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
    {{ $t('project.projectTestSignIn.signsAnEndUserIn') }}
  </BaseAlert>
  <i18n-t keypath="project.projectTestSignIn.testingClient" tag="p" v-if="selectedClient" class="text-sm text-text-muted">
    <template #client><RouterLink :to="{ name: 'project-app-client', params: { projectUid: project?.uid, clientUid: selectedClient.uid } }" class="font-medium text-primary underline">
      {{ selectedClient.name }}</RouterLink></template>
    <template #auditLog><RouterLink :to="{ name: 'project-audit-log', params: { projectUid: project?.uid }, query: { app_client_uid_eq: selectedClient.uid } }" class="font-medium text-primary underline">
      {{ $t('project.projectTestSignIn.auditLog') }}</RouterLink></template>
  </i18n-t>

  <BaseAlert v-if="loadClients.error.value" variant="danger">
    {{ $t('project.projectTestSignIn.clientsLoadFailed', { message: loadClients.error.value.message }) }}
  </BaseAlert>
  <p v-else-if="loadClients.loading.value" class="text-sm text-text-muted" role="status">{{ $t('project.projectTestSignIn.loadingAppClients') }}</p>

  <BaseCard v-else-if="!hasClients" :title="$t('project.projectTestSignIn.noOpenidConnectOrApi')" :description="$t('project.projectTestSignIn.endUsersSignInThrough')">
    <RouterLink
      :to="{ name: 'project-applications', params: { projectUid: project?.uid } }"
      class="self-start text-sm font-medium text-primary underline hover:text-primary-hover"
    >
      {{ $t('project.projectTestSignIn.addAnApplication') }}
    </RouterLink>
  </BaseCard>

  <template v-else>
    <BaseCard v-if="!challenge && !tokens" :title="$t('project.projectTestSignIn.signInAsAnEnd')">
      <form class="flex flex-col gap-4" novalidate @submit.prevent="signIn">
        <BaseAlert v-if="flow.signIn.error.value" variant="danger">
          {{ flow.signIn.error.value.message }}
          <code class="font-mono text-xs">{{ flow.signIn.error.value.code }}</code>
          <p v-if="flow.signIn.error.value && explainSignInError(flow.signIn.error.value.code)" class="text-sm">{{ explainSignInError(flow.signIn.error.value.code) }}</p>
        </BaseAlert>

        <BaseSearchSelect
          v-model="clientUid"
          :label="$t('project.projectTestSignIn.appClient')"
          :search="lookups.searchAppClients"
          :resolve-label="lookups.appClientName"
          :see-all="lookups.allApplications.value"
          :error="loadClient.error.value?.message"
        />
        <BaseInput
          v-if="selectedClient?.client_type === 'confidential'"
          v-model="clientSecret"
          :label="$t('project.projectTestSignIn.clientSecret')"
          type="password"
          autocomplete="off"
          :hint="$t('project.projectTestSignIn.confidentialClientsMustSendTheir')"
          :error="flow.signIn.error.value?.fieldError('client_secret')"
        />
        <BaseInput
          v-model="email"
          :label="$t('project.projectTestSignIn.endUserSEmail')"
          type="email"
          autocomplete="off"
          required
          :error="flow.signIn.error.value?.fieldError('email')"
        />
        <BaseInput
          v-model="password"
          :label="$t('project.projectTestSignIn.password')"
          type="password"
          autocomplete="off"
          required
          :error="flow.signIn.error.value?.fieldError('password')"
        />
        <BaseButton type="submit" :label="$t('project.projectTestSignIn.signIn')" :loading="flow.signIn.loading.value" class="self-start" />
      </form>

      <section class="flex flex-col gap-4 border-t border-border pt-4" aria-labelledby="hosted-login-heading">
        <h3 id="hosted-login-heading" class="text-sm font-semibold">{{ $t('project.projectTestSignIn.orUseHostedLoginOpenid') }}</h3>
        <p class="text-sm text-text-muted">
          {{ $t('project.projectTestSignIn.runsTheAuthorizationCodeFlow') }}
        </p>
        <BaseAlert v-if="hostedLogin.complete.error.value" variant="danger">
          {{ hostedLogin.complete.error.value.message }}
          <code class="font-mono text-xs">{{ hostedLogin.complete.error.value.code }}</code>
          <p v-if="hostedLogin.complete.error.value && explainSignInError(hostedLogin.complete.error.value.code)" class="text-sm">{{ explainSignInError(hostedLogin.complete.error.value.code) }}</p>
        </BaseAlert>
        <p v-if="hostedLogin.complete.loading.value" class="text-sm text-text-muted" role="status">{{ $t('project.projectTestSignIn.finishingHostedSignIn') }}</p>
        <BaseAlert v-if="selectedClient?.client_type === 'confidential'" variant="info">
          {{ $t('project.projectTestSignIn.chooseAPublicAppClient') }}
        </BaseAlert>
        <BaseAlert v-else-if="!hostedLoginReady" variant="warning" :title="$t('project.projectTestSignIn.addThisPageAsA')">
          <i18n-t keypath="project.projectTestSignIn.addRedirectUri">
            <template #uri><code class="font-mono text-xs break-all">{{ hostedRedirectUri }}</code></template>
            <template #client><RouterLink
            v-if="selectedClient"
            :to="{ name: 'project-app-client-sign-in', params: { projectUid: project?.uid, clientUid: selectedClient.uid } }"
            class="font-medium text-primary underline hover:text-primary-hover"
          >
            {{ selectedClient.name }}</RouterLink></template>
          </i18n-t>
        </BaseAlert>
        <div class="flex flex-wrap gap-2">
          <BaseButton
            :label="$t('project.projectTestSignIn.signInWithHostedLogin')"
            variant="secondary"
            :disabled="!hostedLoginReady"
            :loading="hostedLogin.start.loading.value"
            @click="startHostedLogin"
          />
          <BaseButton :label="$t('project.projectTestSignIn.endHostedLoginSession')" variant="ghost" @click="endHostedSession" />
        </div>
      </section>
    </BaseCard>

    <BaseCard v-else-if="challenge" :title="challengeTitle" :description="$t('project.projectTestSignIn.theApiAskedForAnother')">
      <form class="flex flex-col gap-4" novalidate @submit.prevent="flow.answer.run({ code, newPassword })">
        <BaseAlert v-if="flow.answer.error.value && flow.answer.error.value.details.length === 0" variant="danger">
          {{ flow.answer.error.value.message }}
          <code class="font-mono text-xs">{{ flow.answer.error.value.code }}</code>
          <p v-if="flow.answer.error.value && explainSignInError(flow.answer.error.value.code)" class="text-sm">{{ explainSignInError(flow.answer.error.value.code) }}</p>
        </BaseAlert>

        <template v-if="challenge.challenge === 'otp'">
          <p class="text-sm text-text-muted">{{ $t('project.projectTestSignIn.enterACodeFromThe') }}</p>
          <BaseInput
            v-model="code"
            :label="$t('project.projectTestSignIn.verificationCode')"
            autocomplete="off"
            required
            :error="flow.answer.error.value?.fieldError('code')"
          />
        </template>

        <template v-else-if="challenge.challenge === 'new_password'">
          <p class="text-sm text-text-muted">{{ $t('project.projectTestSignIn.theEndUserSPassword') }}</p>
          <BaseInput
            v-model="newPassword"
            :label="$t('project.projectTestSignIn.newPassword')"
            type="password"
            autocomplete="off"
            required
            :error="flow.answer.error.value?.fieldError('new_password')"
          />
        </template>

        <template v-else-if="challenge.challenge === 'mfa_setup'">
          <p class="text-sm text-text-muted">{{ $t('project.projectTestSignIn.theProjectRequiresMfaAnd') }}</p>
          <OtpSetup v-if="enrollment" :enrollment="enrollment" />
          <BaseInput
            v-model="code"
            :label="$t('project.projectTestSignIn.verificationCode')"
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
            :label="$t('project.projectTestSignIn.continue')"
            :loading="flow.answer.loading.value"
          />
          <BaseButton :label="$t('project.projectTestSignIn.startOver')" variant="secondary" @click="startOver" />
        </div>
      </form>
    </BaseCard>

    <template v-else-if="tokens">
      <RecoveryCodesList v-if="recoveryCodes.length > 0" :codes="recoveryCodes" />

      <BaseCard :title="$t('project.projectTestSignIn.signedIn')" :description="$t('project.projectTestSignIn.accessTokenExpiresInSeconds', { expiresIn: tokens.expires_in })">
        <BaseAlert v-if="signedOut" variant="success">
          {{ $t('project.projectTestSignIn.signedOutTheRefreshToken') }}
        </BaseAlert>
        <BaseAlert v-else-if="refreshedAt" variant="success">
          {{ $t('project.projectTestSignIn.refreshedAt', { time: refreshedAt.toLocaleTimeString(currentLocale()) }) }}
        </BaseAlert>
        <BaseAlert v-if="flow.refresh.error.value" variant="danger">
          {{ $t('project.projectTestSignIn.refreshFailed', { message: flow.refresh.error.value.message }) }}
          <code class="font-mono text-xs">{{ flow.refresh.error.value.code }}</code>
          <p v-if="flow.refresh.error.value && explainSignInError(flow.refresh.error.value.code)" class="text-sm">{{ explainSignInError(flow.refresh.error.value.code) }}</p>
        </BaseAlert>
        <BaseAlert v-if="flow.signOut.error.value" variant="danger">
          {{ $t('project.projectTestSignIn.signOutFailed', { message: flow.signOut.error.value.message }) }}
          <code class="font-mono text-xs">{{ flow.signOut.error.value.code }}</code>
          <p v-if="flow.signOut.error.value && explainSignInError(flow.signOut.error.value.code)" class="text-sm">{{ explainSignInError(flow.signOut.error.value.code) }}</p>
        </BaseAlert>

        <div class="flex flex-wrap gap-2">
          <BaseButton :label="$t('project.projectTestSignIn.refreshTokens')" variant="secondary" :loading="flow.refresh.loading.value" @click="flow.refresh.run()" />
          <BaseButton
            :label="$t('project.projectTestSignIn.signOut')"
            variant="secondary"
            :disabled="signedOut"
            :loading="flow.signOut.loading.value"
            @click="flow.signOut.run()"
          />
          <BaseButton :label="$t('project.projectTestSignIn.startOver')" variant="ghost" @click="startOver" />
        </div>

        <DecodedToken :label="$t('project.projectTestSignIn.accessToken')" :token="tokens.access_token" />
        <DecodedToken v-if="tokens.id_token" :label="$t('project.projectTestSignIn.idToken')" :token="tokens.id_token" />
        <DecodedToken :label="$t('project.projectTestSignIn.refreshToken')" :token="tokens.refresh_token" />
      </BaseCard>
    </template>
  </template>
</template>
