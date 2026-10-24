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
</script>

<template>
  <BaseCard title="Client ID" description="Apps send it as client_id. It isn't secret.">
    <code class="font-mono text-sm break-all">{{ client.uid }}</code>
  </BaseCard>

  <BaseCard v-if="client.client_type === 'public'" title="No client secret">
    <p class="text-sm">
      Public clients run in browsers and on devices, where a secret can't be kept, so they don't have one. They prove themselves
      with PKCE, which x-identity requires for every client. The client type can't be changed; create a confidential client for a
      server-side app.
    </p>
  </BaseCard>

  <BaseCard
    v-else
    title="Client secrets"
    :description="
      client.machine
        ? 'The app sends a secret with each token request. Only digests are stored, so secrets can\'t be shown again.'
        : 'Confidential clients send a secret when redeeming codes and refreshing tokens. Only digests are stored, so secrets can\'t be shown again.'
    "
  >
    <BaseAlert v-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
    <ul class="flex flex-col divide-y divide-border">
      <li v-for="secret in secrets" :key="secret.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
        <span class="flex flex-col">
          <code class="font-mono text-xs">{{ secret.last_four ? `••••${secret.last_four}` : 'Secret from before rotation overlap' }}</code>
          <span class="text-xs text-text-muted">
            Created {{ formatDateTime(secret.created_at) }} · {{ secret.last_used_at ? `last used ${formatDateTime(secret.last_used_at)}` : 'not used yet' }}
          </span>
        </span>
        <span class="flex items-center gap-2">
          <StatusBadge :tone="secretStatus(secret).tone" :label="secretStatus(secret).label" />
          <BaseButton
            v-if="access.developer && secret.usable && usableCount > 1"
            label="Revoke"
            variant="ghost"
            size="sm"
            :aria-label="`Revoke secret ending ${secret.last_four ?? ''}`"
            @click="pendingRevoke = secret"
          />
        </span>
      </li>
    </ul>
    <BaseAlert v-if="usableCount > 1" variant="info">
      More than one secret works at the moment. Once every server uses the newest one, revoke the others, or let them expire.
    </BaseAlert>
    <BaseButton v-if="access.developer" label="Rotate secret" variant="secondary" class="self-start" @click="rotateOpen = true" />
    <BaseAlert v-else variant="info">Only project admins and developers can rotate secrets.</BaseAlert>
  </BaseCard>

  <BaseCard
    v-if="client.machine"
    title="Rate limit"
    description="How many token requests this app may make per minute. Requests over the limit get HTTP 429 until the next minute."
  >
    <form class="flex flex-col gap-3" novalidate @submit.prevent="saveLimit.run()">
      <BaseAlert v-if="limitSaved" variant="success">Rate limit saved.</BaseAlert>
      <BaseAlert v-if="saveLimit.error.value && saveLimit.error.value.details.length === 0" variant="danger">{{ saveLimit.error.value.message }}</BaseAlert>
      <BaseCheckbox
        v-model="customLimit"
        label="Use a custom limit for this app"
        :hint="settings ? `Otherwise the project's limit applies: ${settings.token_requests_per_minute} per minute.` : undefined"
        :disabled="!access.developer"
      />
      <div v-if="customLimit" class="max-w-xs">
        <BaseInput
          v-model="limit"
          label="Token requests per minute"
          type="number"
          hint="10–10,000."
          :disabled="!access.developer"
          :error="saveLimit.error.value?.fieldError('token_requests_per_minute')"
        />
      </div>
      <BaseButton v-if="access.developer" type="submit" label="Save rate limit" variant="secondary" class="self-start" :loading="saveLimit.loading.value" />
    </form>
  </BaseCard>

  <BaseCard v-if="client.machine" title="Getting a token" description="With the client credentials grant, from the app's server.">
    <pre class="overflow-x-auto rounded-md bg-bg-subtle p-3 font-mono text-xs">curl -X POST {{ tokenEndpoint }} \
  -u '{{ client.uid }}:CLIENT_SECRET' \
  -d grant_type=client_credentials \
  -d audience=API_IDENTIFIER \
  -d 'scope=SCOPES'</pre>
    <p class="text-xs text-text-muted">
      Leave out <code class="font-mono">audience</code> when the app can use only one API, and <code class="font-mono">scope</code> to get
      every scope it's allowed. Request a new token shortly before the last one expires; there are no refresh tokens.
    </p>
  </BaseCard>

  <ConfirmDialog v-model:visible="rotateOpen" title="Rotate the client secret?" confirm-label="Rotate secret" :loading="rotate.loading.value" :error="rotate.error.value" @confirm="rotate.run()">
    <p v-if="overlap === 0">
      <strong>{{ client.name }}</strong> gets a new secret, and the current one <strong>stops working at once</strong>, because this
      project's rotation overlap is 0. Servers using it fail until they're updated.
    </p>
    <p v-else>
      <strong>{{ client.name }}</strong> gets a new secret. The current one keeps working for
      {{ overlap === null ? 'the project\'s rotation overlap' : formatDuration(overlap) }}, so you can update every server before it stops;
      you can also revoke it sooner.
    </p>
  </ConfirmDialog>

  <ConfirmDialog
    :visible="pendingRevoke !== null"
    title="Revoke this secret now?"
    confirm-label="Revoke secret"
    danger
    :loading="revoke.loading.value"
    :error="revoke.error.value"
    @update:visible="(open: boolean) => !open && (pendingRevoke = null)"
    @confirm="pendingRevoke && revoke.run(pendingRevoke)"
  >
    <p>Servers still using the secret ending <code class="font-mono">{{ pendingRevoke?.last_four }}</code> stop working at once.</p>
  </ConfirmDialog>

  <BaseDialog :visible="newSecret !== null" title="Copy the new secret" @update:visible="(open: boolean) => !open && (newSecret = null)">
    <code class="font-mono text-xs break-all">{{ newSecret }}</code>
    <BaseAlert variant="warning" title="It won't be shown again">Keep it on your server only; never put it in a browser or mobile app.</BaseAlert>
    <template #footer>
      <BaseButton label="I've copied it" @click="newSecret = null" />
    </template>
  </BaseDialog>
</template>
