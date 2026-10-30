<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useAppClient } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AppClientSecret, AuthConfiguration } from '@/types/api'
import { secretStatus } from '@/utils/appClientSecrets'
import { formatDateTime, formatDuration } from '@/utils/format'

const { accountUid, project, access } = useProjectContext()
const { record: client, replace } = useAppClient()

const secrets = ref<AppClientSecret[]>([])
const settings = ref<AuthConfiguration | null>(null)
const customLimit = ref(false)
const limit = ref('')
const limitSaved = ref(false)
const rotateOpen = ref(false)
const newSecret = ref<string | null>(null)
const pendingRevoke = ref<AppClientSecret | null>(null)

const usableCount = computed(() => secrets.value.filter((secret) => secret.usable).length)
const tokenEndpoint = computed(() => `${project.value?.token_issuer ?? ''}/oauth2/token`)
const overlap = computed(() => settings.value?.client_secret_rotation_overlap_seconds ?? null)

const load = useAsyncAction(async () => {
  if (!project.value) return
  customLimit.value = client.value.token_requests_per_minute !== null
  limit.value = client.value.token_requests_per_minute?.toString() ?? ''
  const [loadedSettings, loadedSecrets] = await Promise.all([
    projectAdminService.getAuthConfiguration(accountUid.value, project.value.uid),
    client.value.client_type === 'confidential' ? projectAdminService.listAppClientSecrets(accountUid.value, project.value.uid, client.value.uid) : [],
  ])
  settings.value = loadedSettings
  secrets.value = loadedSecrets
})

const saveLimit = useAsyncAction(async () => {
  if (!project.value) return
  limitSaved.value = false
  const updated = await projectAdminService.updateAppClient(accountUid.value, project.value.uid, client.value.uid, {
    token_requests_per_minute: customLimit.value ? Number(limit.value) : null,
  })
  replace(updated)
  limitSaved.value = true
})

const rotate = useAsyncAction(async () => {
  if (!project.value) return
  const rotated = await projectAdminService.rotateAppClientSecret(accountUid.value, project.value.uid, client.value.uid)
  newSecret.value = rotated.client_secret
  replace(rotated)
  rotateOpen.value = false
  await load.run()
})

const revoke = useAsyncAction(async (secret: AppClientSecret) => {
  if (!project.value) return
  await projectAdminService.revokeAppClientSecret(accountUid.value, project.value.uid, client.value.uid, secret.uid)
  pendingRevoke.value = null
  await load.run()
})

onMounted(() => load.run())

const curlExample = computed(() =>
  [
    `curl -X POST ${tokenEndpoint.value} \\`,
    `  -u '${client.value.uid}:CLIENT_SECRET' \\`,
    '  -d grant_type=client_credentials \\',
    '  -d audience=API_IDENTIFIER \\',
    "  -d 'scope=SCOPES'",
  ].join('\n'),
)
</script>

<template>
  <BaseCard :title="$t('project.appClientCredentials.clientId')" :description="$t('project.appClientCredentials.appsSendItAsClient')">
    <code class="font-mono text-sm break-all">{{ client.uid }}</code>
  </BaseCard>

  <BaseCard v-if="client.client_type === 'public'" :title="$t('project.appClientCredentials.noClientSecret')">
    <p class="text-sm">
      {{ $t('project.appClientCredentials.publicClientsRunInBrowsers') }}
    </p>
  </BaseCard>

  <BaseCard
    v-else
    :title="$t('project.appClientCredentials.clientSecrets')"
    :description="
      client.machine
        ? $t('project.appClientCredentials.theAppSendsASecret')
        : $t('project.appClientCredentials.confidentialClientsSendASecret')
    "
  >
    <BaseAlert v-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
    <ul class="flex flex-col divide-y divide-border">
      <li v-for="secret in secrets" :key="secret.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
        <span class="flex flex-col">
          <code class="font-mono text-xs">{{ secret.last_four ? `••••${secret.last_four}` : $t('project.appClientCredentials.secretFromBeforeRotationOverlap') }}</code>
          <span class="text-xs text-text-muted">
            {{
              $t('project.appClientCredentials.secretDates', {
                created: formatDateTime(secret.created_at),
                used: secret.last_used_at
                  ? $t('project.appClientCredentials.lastUsed', { date: formatDateTime(secret.last_used_at) })
                  : $t('project.appClientCredentials.notUsedYet'),
              })
            }}
          </span>
        </span>
        <span class="flex items-center gap-2">
          <StatusBadge :tone="secretStatus(secret).tone" :label="secretStatus(secret).label" />
          <BaseButton
            v-if="access.developer && secret.usable && usableCount > 1"
            :label="$t('project.appClientCredentials.revoke')"
            variant="ghost"
            size="sm"
            :aria-label="$t('project.appClientCredentials.revokeSecretEnding', { lastFour: secret.last_four ?? '' })"
            @click="pendingRevoke = secret"
          />
        </span>
      </li>
    </ul>
    <BaseAlert v-if="usableCount > 1" variant="info">
      {{ $t('project.appClientCredentials.moreThanOneSecretWorks') }}
    </BaseAlert>
    <BaseButton v-if="access.developer" :label="$t('project.appClientCredentials.rotateSecret')" variant="secondary" class="self-start" @click="rotateOpen = true" />
    <BaseAlert v-else variant="info">{{ $t('project.appClientCredentials.onlyProjectAdminsAndDevelopers') }}</BaseAlert>
  </BaseCard>

  <BaseCard
    v-if="client.machine"
    :title="$t('project.appClientCredentials.rateLimit')"
    :description="$t('project.appClientCredentials.howManyTokenRequestsThis')"
  >
    <form class="flex flex-col gap-3" novalidate @submit.prevent="saveLimit.run()">
      <BaseAlert v-if="limitSaved" variant="success">{{ $t('project.appClientCredentials.rateLimitSaved') }}</BaseAlert>
      <BaseAlert v-if="saveLimit.error.value && saveLimit.error.value.details.length === 0" variant="danger">{{ saveLimit.error.value.message }}</BaseAlert>
      <BaseCheckbox
        v-model="customLimit"
        :label="$t('project.appClientCredentials.useACustomLimitFor')"
        :hint="settings ? $t('project.appClientCredentials.otherwiseTheProjectSLimit', { tokenRequestsPerMinute: settings.token_requests_per_minute }) : undefined"
        :disabled="!access.developer"
      />
      <div v-if="customLimit" class="max-w-xs">
        <BaseInput
          v-model="limit"
          :label="$t('project.appClientCredentials.tokenRequestsPerMinute')"
          type="number"
          :hint="$t('project.appClientCredentials.tokenLimitRange')"
          :disabled="!access.developer"
          :error="saveLimit.error.value?.fieldError('token_requests_per_minute')"
        />
      </div>
      <BaseButton v-if="access.developer" type="submit" :label="$t('project.appClientCredentials.saveRateLimit')" variant="secondary" class="self-start" :loading="saveLimit.loading.value" />
    </form>
  </BaseCard>

  <BaseCard v-if="client.machine" :title="$t('project.appClientCredentials.gettingAToken')" :description="$t('project.appClientCredentials.withTheClientCredentialsGrant')">
    <pre class="overflow-x-auto rounded-md bg-bg-subtle p-3 font-mono text-xs">{{ curlExample }}</pre>
    <i18n-t keypath="project.appClientCredentials.leaveOutAudience" tag="p" class="text-xs text-text-muted">
      <template #audience><code class="font-mono">{{ $t('project.appClientCredentials.audience') }}</code></template>
      <template #scope><code class="font-mono">{{ $t('project.appClientCredentials.scope') }}</code></template>
    </i18n-t>
  </BaseCard>

  <ConfirmDialog v-model:visible="rotateOpen" :title="$t('project.appClientCredentials.rotateTheClientSecret')" :confirm-label="$t('project.appClientCredentials.rotateSecret')" :loading="rotate.loading.value" :error="rotate.error.value" @confirm="rotate.run()">
    <i18n-t keypath="project.appClientCredentials.rotateNoOverlap" tag="p" v-if="overlap === 0">
      <template #name><strong>{{ client.name }}</strong></template>
      <template #atOnce><strong>{{ $t('project.appClientCredentials.stopsWorkingAtOnce') }}</strong></template>
    </i18n-t>
    <i18n-t v-else keypath="project.appClientCredentials.rotateWithOverlap" tag="p">
      <template #name><strong>{{ client.name }}</strong></template>
      <template #overlap>{{ overlap === null ? $t('project.appClientCredentials.projectOverlap') : formatDuration(overlap) }}</template>
    </i18n-t>
  </ConfirmDialog>

  <ConfirmDialog
    :visible="pendingRevoke !== null"
    :title="$t('project.appClientCredentials.revokeThisSecretNow')"
    :confirm-label="$t('project.appClientCredentials.revokeSecret')"
    danger
    :loading="revoke.loading.value"
    :error="revoke.error.value"
    @update:visible="(open: boolean) => !open && (pendingRevoke = null)"
    @confirm="pendingRevoke && revoke.run(pendingRevoke)"
  >
    <i18n-t keypath="project.appClientCredentials.revokeDescription" tag="p">
      <template #lastFour><code class="font-mono">{{ pendingRevoke?.last_four }}</code></template>
    </i18n-t>
  </ConfirmDialog>

  <BaseDialog :visible="newSecret !== null" :title="$t('project.appClientCredentials.copyTheNewSecret')" @update:visible="(open: boolean) => !open && (newSecret = null)">
    <code class="font-mono text-xs break-all">{{ newSecret }}</code>
    <BaseAlert variant="warning" :title="$t('project.appClientCredentials.itWonTBeShown')">{{ $t('project.appClientCredentials.keepItOnYourServer') }}</BaseAlert>
    <template #footer>
      <BaseButton :label="$t('project.appClientCredentials.iVeCopiedIt')" @click="newSecret = null" />
    </template>
  </BaseDialog>
</template>
