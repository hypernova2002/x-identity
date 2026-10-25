<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { DataTableColumn, DataTableFilter, SelectOption } from '@/components/base/types'
import StatCards from '@/components/console/StatCards.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import SamlAppForm from '@/components/project/SamlAppForm.vue'
import RoutePageHeader from '@/components/console/RoutePageHeader.vue'
import { useAsync } from '@/composables/useAsync'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useListView } from '@/composables/useListView'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AppClientType, AppClientWithSecret, Application } from '@/types/api'
import { formatDateTime } from '@/utils/format'
import { appClientTypeOptions, yesNoOptions } from '@/utils/options'
import { emptySamlAppDraft, samlAppInputFrom, withMetadata, type SamlAppDraft } from '@/utils/samlApps'

const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const typeOptions: SelectOption<'oidc' | 'machine' | 'saml'>[] = [
  { label: 'OpenID Connect / API', value: 'oidc' },
  { label: 'Machine-to-machine', value: 'machine' },
  { label: 'SAML', value: 'saml' },
]
const newKindOptions: SelectOption<'oidc' | 'saml' | 'machine'>[] = [
  { label: 'OpenID Connect or API client: your own apps, using hosted login, an OIDC library or the sign-in API', value: 'oidc' },
  { label: 'SAML application: apps that only support SAML 2.0, such as many SaaS tools', value: 'saml' },
  { label: 'Machine-to-machine: a service or job that calls your APIs with its own credentials, no user involved', value: 'machine' },
]

const columns: DataTableColumn[] = [
  { key: 'name', label: 'Application', sortKey: 'name' },
  { key: 'app_type', label: 'Type', sortKey: 'type' },
  { key: 'enabled', label: 'Status' },
  { key: 'created_at', label: 'Created', sortKey: 'created_at' },
]
const filters: DataTableFilter[] = [
  { type: 'select', key: 'kind_eq', label: 'Type', options: typeOptions },
  { type: 'select', key: 'enabled_eq', label: 'Enabled', options: yesNoOptions },
]

const list = useListView((params) => projectAdminService.listApplications(accountUid.value, project.value!.uid, params), {
  defaultSort: 'name',
  storageKey: 'applications',
  filterKeys: filters.map((filter) => filter.key),
  syncRoute: true,
})
const listState = list.state

const detailRoute = (row: Pick<Application, 'app_type' | 'uid'>) =>
  row.app_type === 'saml_app'
    ? { name: 'project-saml-app', params: { projectUid: project.value?.uid, samlAppUid: row.uid } }
    : { name: 'project-app-client', params: { projectUid: project.value?.uid, clientUid: row.uid } }

// Adding an application: choose the kind, then fill in its form.
const addOpen = ref(false)
const newKind = ref<'oidc' | 'saml' | 'machine'>('oidc')
const step = ref<'kind' | 'oidc' | 'saml' | 'machine'>('kind')
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
  const machine = step.value === 'machine'
  const client = await projectAdminService.createAppClient(accountUid.value, project.value.uid, {
    name: clientName.value,
    client_type: machine ? 'confidential' : clientType.value,
    machine,
    allowed_origins: [],
    redirect_uris: [],
    post_logout_redirect_uris: [],
    launch_url: null,
  })
  addOpen.value = false
  if (client.client_secret) created.value = client
  else await router.push(detailRoute({ app_type: 'app_client', uid: client.uid }))
})

const stats = useAsync(() => projectAdminService.applicationStats(accountUid.value, project.value!.uid))
const statCards = computed(() => [
  { label: 'Applications', value: stats.data.value?.total },
  { label: 'OpenID Connect', value: stats.data.value?.oidc },
  { label: 'SAML', value: stats.data.value?.saml },
  { label: 'Machine-to-machine', value: stats.data.value?.machine },
])

function reloadAll() {
  list.reload()
  stats.reload()
}

onMounted(() => stats.reload())

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

</script>

<template>
  <RoutePageHeader>
    <template v-if="access.developer" #actions>
      <BaseButton label="Add application" @click="startAdding" />
    </template>
  </RoutePageHeader>

  <StatCards label="Application counts" :cards="statCards" :loading="stats.loading.value" :error="stats.error.value" @retry="stats.reload" />

  <BaseDataTable
    storage-key="applications"
    v-model:state="listState"
    caption="Applications"
    search-placeholder="Search applications…"
    search-label="Search by name or ID"
    :columns="columns"
    :filters="filters"
    :rows="list.rows.value"
    :row-key="(row) => `${row.app_type}-${row.uid}`"
    :total="list.total.value"
    :per-page="list.perPage.value"
    :loading="list.loading.value"
    :error="list.error.value"
    empty-message="No applications yet. Add one for each app that signs this project's end users in."
    @reload="reloadAll"
  >
    <template #cell-name="{ row }">
      <RouterLink :to="detailRoute(row)" class="font-medium text-primary underline-offset-2 hover:underline">{{ row.name }}</RouterLink>
      <code class="block font-mono text-xs break-all text-text-muted">{{ row.uid }}</code>
    </template>
    <template #cell-app_type="{ row }">
      <StatusBadge tone="info" :label="row.app_type === 'saml_app' ? 'SAML' : row.machine ? 'Machine-to-machine' : 'OpenID Connect / API'" />
      <span class="mt-1 block text-xs break-all text-text-muted">
        {{
          row.app_type === 'saml_app'
            ? row.entity_id
            : row.machine
              ? 'Gets tokens for your APIs'
              : row.client_type === 'public'
                ? 'Public client (no secret)'
                : 'Confidential client'
        }}
      </span>
    </template>
    <template #cell-enabled="{ row }">
      <StatusBadge :tone="row.enabled ? 'success' : 'neutral'" :label="row.enabled ? 'Enabled' : 'Disabled'" />
    </template>
    <template #cell-created_at="{ row }"><span class="text-xs">{{ formatDateTime(row.created_at) }}</span></template>
  </BaseDataTable>

  <p class="text-sm text-text-muted">
    External systems that end users sign in <em>with</em> (Google, Apple, companies' identity providers) are configured under
    <RouterLink :to="{ name: 'project-identity-providers', params: { projectUid: project?.uid } }" class="font-medium text-primary underline">
      Identity providers</RouterLink>, not here.
  </p>

  <BaseDialog v-model:visible="addOpen" title="Add application">
    <template v-if="step === 'kind'">
      <BaseSelect v-model="newKind" label="What kind of application?" :options="newKindOptions" />
    </template>

    <form v-else-if="step === 'oidc' || step === 'machine'" id="create-client" class="flex flex-col gap-4" novalidate @submit.prevent="createClient.run()">
      <BaseAlert v-if="createClient.error.value && createClient.error.value.details.length === 0" variant="danger">
        {{ createClient.error.value.message }}
      </BaseAlert>
      <BaseInput
        v-model="clientName"
        label="Name"
        required
        :hint="step === 'machine' ? 'For example Billing job or Inventory sync.' : 'For example Web shop or iOS app.'"
        :error="createClient.error.value?.fieldError('name')"
      />
      <p v-if="step === 'machine'" class="text-xs text-text-muted">
        It gets a client secret. Next, give it access to your APIs; it can't get tokens until it has some.
      </p>
      <BaseSelect
        v-if="step === 'oidc'"
        v-model="clientType"
        label="Client type"
        :options="appClientTypeOptions"
        hint="Public for browser and mobile apps; confidential for server-side apps that can keep a secret. It can't be changed later."
      />
      <p v-if="step === 'oidc'" class="text-xs text-text-muted">Next, add its redirect URIs and give users access. Nobody can sign in until it's assigned.</p>
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
      <BaseButton v-else-if="step === 'oidc' || step === 'machine'" label="Create client" type="submit" form="create-client" :loading="createClient.loading.value" />
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
      <BaseButton
        v-if="created"
        label="I've copied it"
        @click="
          router.push(
            created.machine
              ? { name: 'project-app-client-api-access', params: { projectUid: project?.uid, clientUid: created.uid } }
              : detailRoute({ app_type: 'app_client', uid: created.uid }),
          )
        "
      />
    </template>
  </BaseDialog>
</template>
