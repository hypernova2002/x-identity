<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import type { SelectOption } from '@/components/base/types'
import StatusBadge from '@/components/console/StatusBadge.vue'
import SamlAppForm from '@/components/project/SamlAppForm.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AppClient, AppClientType, AppClientWithSecret, SamlApp } from '@/types/api'
import { formatDateTime } from '@/utils/format'
import { appClientTypeOptions } from '@/utils/options'
import { emptySamlAppDraft, samlAppInputFrom, withMetadata, type SamlAppDraft } from '@/utils/samlApps'

type Protocol = 'all' | 'oidc' | 'saml'

interface Row {
  kind: 'oidc' | 'saml'
  uid: string
  name: string
  enabled: boolean
  detail: string
  createdAt: string
}

const route = useRoute()
const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const clients = ref<AppClient[]>([])
const samlApps = ref<SamlApp[]>([])
const search = ref('')
const protocol = ref<Protocol>(['oidc', 'saml'].includes(String(route.query.type)) ? (route.query.type as Protocol) : 'all')

const protocolOptions: SelectOption<Protocol>[] = [
  { label: 'All applications', value: 'all' },
  { label: 'OpenID Connect and API clients', value: 'oidc' },
  { label: 'SAML applications', value: 'saml' },
]
const newKindOptions: SelectOption<'oidc' | 'saml'>[] = [
  { label: 'OpenID Connect or API client: your own apps, using hosted login, an OIDC library or the sign-in API', value: 'oidc' },
  { label: 'SAML application: apps that only support SAML 2.0, such as many SaaS tools', value: 'saml' },
]

const rows = computed<Row[]>(() => {
  const all: Row[] = [
    ...clients.value.map((client) => ({
      kind: 'oidc' as const,
      uid: client.uid,
      name: client.name,
      enabled: client.enabled,
      detail: client.client_type === 'public' ? 'Public client (no secret)' : 'Confidential client',
      createdAt: client.created_at,
    })),
    ...samlApps.value.map((app) => ({ kind: 'saml' as const, uid: app.uid, name: app.name, enabled: app.enabled, detail: app.entity_id, createdAt: app.created_at })),
  ]
  const term = search.value.trim().toLowerCase()
  return all
    .filter((row) => protocol.value === 'all' || row.kind === protocol.value)
    .filter((row) => !term || row.name.toLowerCase().includes(term) || row.uid.toLowerCase().includes(term))
    .sort((a, b) => a.name.localeCompare(b.name))
})

const columns = [
  { key: 'name', label: 'Application' },
  { key: 'kind', label: 'Type' },
  { key: 'enabled', label: 'Status' },
  { key: 'createdAt', label: 'Created' },
]

const detailRoute = (row: Pick<Row, 'kind' | 'uid'>) =>
  row.kind === 'saml'
    ? { name: 'project-saml-app', params: { projectUid: project.value?.uid, samlAppUid: row.uid } }
    : { name: 'project-app-client', params: { projectUid: project.value?.uid, clientUid: row.uid } }

function setProtocol(value: Protocol) {
  protocol.value = value
  router.replace({ query: value === 'all' ? {} : { type: value } })
}

const load = useAsyncAction(async () => {
  if (!project.value) return
  const [loadedClients, loadedSamlApps] = await Promise.all([
    projectAdminService.listAppClients(accountUid.value, project.value.uid),
    projectAdminService.listSamlApps(accountUid.value, project.value.uid),
  ])
  clients.value = loadedClients.items
  samlApps.value = loadedSamlApps.items
})

// Adding an application: choose the kind, then fill in its form.
const addOpen = ref(false)
const newKind = ref<'oidc' | 'saml'>('oidc')
const step = ref<'kind' | 'oidc' | 'saml'>('kind')
const clientName = ref('')
const clientType = ref<AppClientType>('public')
const samlDraft = ref<SamlAppDraft>(emptySamlAppDraft())
const created = ref<AppClientWithSecret | null>(null)

function startAdding() {
  step.value = 'kind'
  clientName.value = ''
  clientType.value = 'public'
  samlDraft.value = emptySamlAppDraft()
  createClient.error.value = null
  createSamlApp.error.value = null
  addOpen.value = true
}

const createClient = useAsyncAction(async () => {
  if (!project.value) return
  const client = await projectAdminService.createAppClient(accountUid.value, project.value.uid, {
    name: clientName.value,
    client_type: clientType.value,
    allowed_origins: [],
    redirect_uris: [],
    post_logout_redirect_uris: [],
    launch_url: null,
  })
  addOpen.value = false
  if (client.client_secret) created.value = client
  else await router.push(detailRoute({ kind: 'oidc', uid: client.uid }))
})

const importMetadata = useAsyncAction(async (source: { metadata_xml: string } | { metadata_url: string }) => {
  if (!project.value) return
  samlDraft.value = withMetadata(samlDraft.value, await projectAdminService.parseSamlMetadata(accountUid.value, project.value.uid, source))
})

const createSamlApp = useAsyncAction(async () => {
  if (!project.value) return
  const app = await projectAdminService.createSamlApp(accountUid.value, project.value.uid, samlAppInputFrom(samlDraft.value))
  addOpen.value = false
  await router.push({ name: 'project-saml-app-access', params: { projectUid: project.value.uid, samlAppUid: app.uid } })
})

onMounted(() => load.run())
</script>

<template>
  <BaseCard>
    <div class="flex flex-wrap items-end justify-between gap-4">
      <form class="flex flex-wrap items-end gap-4" role="search" @submit.prevent>
        <div class="w-full max-w-xs">
          <BaseInput v-model="search" label="Search by name or ID" type="search" />
        </div>
        <div class="w-full max-w-xs">
          <BaseSelect :model-value="protocol" label="Type" :options="protocolOptions" @update:model-value="setProtocol" />
        </div>
      </form>
      <BaseButton v-if="access.developer" label="Add application" @click="startAdding" />
    </div>

    <BaseAlert v-if="load.error.value" variant="danger">We couldn't load applications. {{ load.error.value.message }}</BaseAlert>

    <BaseTable
      caption="Applications"
      :columns="columns"
      :rows="rows"
      :row-key="(row) => `${row.kind}-${row.uid}`"
      :loading="load.loading.value"
      :empty-message="
        search || protocol !== 'all'
          ? 'No applications match these filters.'
          : 'No applications yet. Add one for each app that signs this project\'s end users in.'
      "
    >
      <template #cell-name="{ row }">
        <RouterLink :to="detailRoute(row)" class="font-medium text-primary underline-offset-2 hover:underline">{{ row.name }}</RouterLink>
        <code class="block font-mono text-xs break-all text-text-muted">{{ row.uid }}</code>
      </template>
      <template #cell-kind="{ row }">
        <StatusBadge tone="info" :label="row.kind === 'saml' ? 'SAML' : 'OpenID Connect / API'" />
        <span class="mt-1 block text-xs break-all text-text-muted">{{ row.detail }}</span>
      </template>
      <template #cell-enabled="{ row }">
        <StatusBadge :tone="row.enabled ? 'success' : 'neutral'" :label="row.enabled ? 'Enabled' : 'Disabled'" />
      </template>
      <template #cell-createdAt="{ row }"><span class="text-xs">{{ formatDateTime(row.createdAt) }}</span></template>
    </BaseTable>
  </BaseCard>

  <p class="text-sm text-text-muted">
    External systems that end users sign in <em>with</em> (Google, Apple, companies' identity providers) are configured under
    <RouterLink :to="{ name: 'project-identity-providers', params: { projectUid: project?.uid } }" class="font-medium text-primary underline">
      Identity providers</RouterLink>, not here.
  </p>

  <BaseDialog v-model:visible="addOpen" title="Add application">
    <template v-if="step === 'kind'">
      <BaseSelect v-model="newKind" label="What kind of application?" :options="newKindOptions" />
    </template>

    <form v-else-if="step === 'oidc'" id="create-client" class="flex flex-col gap-4" novalidate @submit.prevent="createClient.run()">
      <BaseAlert v-if="createClient.error.value && createClient.error.value.details.length === 0" variant="danger">
        {{ createClient.error.value.message }}
      </BaseAlert>
      <BaseInput v-model="clientName" label="Name" required hint="For example Web shop or iOS app." :error="createClient.error.value?.fieldError('name')" />
      <BaseSelect
        v-model="clientType"
        label="Client type"
        :options="appClientTypeOptions"
        hint="Public for browser and mobile apps; confidential for server-side apps that can keep a secret. It can't be changed later."
      />
      <p class="text-xs text-text-muted">Next, add its redirect URIs and give users access. Nobody can sign in until it's assigned.</p>
    </form>

    <SamlAppForm
      v-else
      v-model="samlDraft"
      form-id="create-saml-app"
      :error="createSamlApp.error.value"
      :import-error="importMetadata.error.value"
      :importing="importMetadata.loading.value"
      @submit="createSamlApp.run()"
      @import-metadata="(source) => importMetadata.run(source)"
    />

    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="addOpen = false" />
      <BaseButton v-if="step === 'kind'" label="Continue" @click="step = newKind" />
      <BaseButton v-else-if="step === 'oidc'" label="Create client" type="submit" form="create-client" :loading="createClient.loading.value" />
      <BaseButton v-else label="Add SAML application" type="submit" form="create-saml-app" :loading="createSamlApp.loading.value" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="created !== null" title="Copy the client secret" @update:visible="(open: boolean) => !open && (created = null)">
    <dl v-if="created" class="grid gap-2 text-sm">
      <dt class="font-medium">Client ID</dt>
      <dd><code class="font-mono text-xs break-all">{{ created.uid }}</code></dd>
      <dt class="font-medium">Client secret</dt>
      <dd><code class="font-mono text-xs break-all">{{ created.client_secret }}</code></dd>
    </dl>
    <BaseAlert variant="warning" title="It won't be shown again">
      Keep it on your server only; never put it in a browser or mobile app. You can rotate it later.
    </BaseAlert>
    <template #footer>
      <BaseButton v-if="created" label="I've copied it" @click="router.push(detailRoute({ kind: 'oidc', uid: created.uid }))" />
    </template>
  </BaseDialog>
</template>
