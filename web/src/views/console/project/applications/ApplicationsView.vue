<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
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

const { t } = useI18n()

const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const typeOptions: SelectOption<'oidc' | 'machine' | 'saml'>[] = [
  { label: t('project.applications.openidConnectApi'), value: 'oidc' },
  { label: t('project.applications.machineToMachine'), value: 'machine' },
  { label: t('project.applications.saml'), value: 'saml' },
]
const newKindOptions: SelectOption<'oidc' | 'saml' | 'machine'>[] = [
  { label: t('project.applications.openidConnectOrApiClient'), value: 'oidc' },
  { label: t('project.applications.samlApplicationAppsThatOnly'), value: 'saml' },
  { label: t('project.applications.machineToMachineAService'), value: 'machine' },
]

const columns: DataTableColumn[] = [
  { key: 'name', label: t('project.applications.application'), sortKey: 'name' },
  { key: 'app_type', label: t('project.applications.type'), sortKey: 'type' },
  { key: 'enabled', label: t('project.applications.status') },
  { key: 'created_at', label: t('project.applications.created'), sortKey: 'created_at' },
]
const filters: DataTableFilter[] = [
  { type: 'select', key: 'kind_eq', label: t('project.applications.type'), options: typeOptions },
  { type: 'select', key: 'enabled_eq', label: t('project.applications.enabled'), options: yesNoOptions },
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
  { label: t('project.applications.applications'), value: stats.data.value?.total },
  { label: t('project.applications.openidConnect'), value: stats.data.value?.oidc },
  { label: t('project.applications.saml'), value: stats.data.value?.saml },
  { label: t('project.applications.machineToMachine'), value: stats.data.value?.machine },
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
      <BaseButton :label="$t('project.applications.addApplication')" @click="startAdding" />
    </template>
  </RoutePageHeader>

  <StatCards :label="$t('project.applications.applicationCounts')" :cards="statCards" :loading="stats.loading.value" :error="stats.error.value" @retry="stats.reload" />

  <BaseDataTable
    storage-key="applications"
    v-model:state="listState"
    :caption="$t('project.applications.applications')"
    :search-placeholder="$t('project.applications.searchApplications')"
    :search-label="$t('project.applications.searchByNameOrId')"
    :columns="columns"
    :filters="filters"
    :rows="list.rows.value"
    :row-key="(row) => `${row.app_type}-${row.uid}`"
    :total="list.total.value"
    :per-page="list.perPage.value"
    :loading="list.loading.value"
    :error="list.error.value"
    :empty-message="$t('project.applications.noApplicationsYetAddOne')"
    @reload="reloadAll"
  >
    <template #cell-name="{ row }">
      <RouterLink :to="detailRoute(row)" class="font-medium text-primary underline-offset-2 hover:underline">{{ row.name }}</RouterLink>
      <code class="block font-mono text-xs break-all text-text-muted">{{ row.uid }}</code>
    </template>
    <template #cell-app_type="{ row }">
      <StatusBadge tone="info" :label="row.app_type === 'saml_app' ? $t('project.applications.saml') : row.machine ? $t('project.applications.machineToMachine') : $t('project.applications.openidConnectApi')" />
      <span class="mt-1 block text-xs break-all text-text-muted">
        {{
          row.app_type === 'saml_app'
            ? row.entity_id
            : row.machine
              ? $t('project.applications.getsTokensForYourApis')
              : row.client_type === 'public'
                ? $t('project.applications.publicClientNoSecret')
                : $t('project.applications.confidentialClient')
        }}
      </span>
    </template>
    <template #cell-enabled="{ row }">
      <StatusBadge :tone="row.enabled ? 'success' : 'neutral'" :label="row.enabled ? $t('project.applications.enabled') : $t('project.applications.disabled')" />
    </template>
    <template #cell-created_at="{ row }"><span class="text-xs">{{ formatDateTime(row.created_at) }}</span></template>
  </BaseDataTable>

  <i18n-t keypath="project.applications.identityProvidersNote" tag="p" class="text-sm text-text-muted">
    <template #signInWith><em>{{ $t('project.applications.with') }}</em></template>
    <template #link><RouterLink :to="{ name: 'project-identity-providers', params: { projectUid: project?.uid } }" class="font-medium text-primary underline">
      {{ $t('project.applications.identityProviders') }}</RouterLink></template>
  </i18n-t>

  <BaseDialog v-model:visible="addOpen" :title="$t('project.applications.addApplication')">
    <template v-if="step === 'kind'">
      <BaseSelect v-model="newKind" :label="$t('project.applications.whatKindOfApplication')" :options="newKindOptions" />
    </template>

    <form v-else-if="step === 'oidc' || step === 'machine'" id="create-client" class="flex flex-col gap-4" novalidate @submit.prevent="createClient.run()">
      <BaseAlert v-if="createClient.error.value && createClient.error.value.details.length === 0" variant="danger">
        {{ createClient.error.value.message }}
      </BaseAlert>
      <BaseInput
        v-model="clientName"
        :label="$t('project.applications.name')"
        required
        :hint="step === 'machine' ? $t('project.applications.forExampleBillingJobOr') : $t('project.applications.forExampleWebShopOr')"
        :error="createClient.error.value?.fieldError('name')"
      />
      <p v-if="step === 'machine'" class="text-xs text-text-muted">
        {{ $t('project.applications.itGetsAClientSecret') }}
      </p>
      <BaseSelect
        v-if="step === 'oidc'"
        v-model="clientType"
        :label="$t('project.applications.clientType')"
        :options="appClientTypeOptions"
        :hint="$t('project.applications.publicForBrowserAndMobile')"
      />
      <p v-if="step === 'oidc'" class="text-xs text-text-muted">{{ $t('project.applications.nextAddItsRedirectUris') }}</p>
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
      <BaseButton :label="$t('project.applications.cancel')" variant="secondary" @click="addOpen = false" />
      <BaseButton v-if="step === 'kind'" :label="$t('project.applications.continue')" @click="step = newKind" />
      <BaseButton v-else-if="step === 'oidc' || step === 'machine'" :label="$t('project.applications.createClient')" type="submit" form="create-client" :loading="createClient.loading.value" />
      <BaseButton v-else :label="$t('project.applications.addSamlApplication')" type="submit" form="create-saml-app" :loading="createSamlApp.loading.value" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="created !== null" :title="$t('project.applications.copyTheClientSecret')" @update:visible="(open: boolean) => !open && (created = null)">
    <dl v-if="created" class="grid gap-2 text-sm">
      <dt class="font-medium">{{ $t('project.applications.clientId') }}</dt>
      <dd><code class="font-mono text-xs break-all">{{ created.uid }}</code></dd>
      <dt class="font-medium">{{ $t('project.applications.clientSecret') }}</dt>
      <dd><code class="font-mono text-xs break-all">{{ created.client_secret }}</code></dd>
    </dl>
    <BaseAlert variant="warning" :title="$t('project.applications.itWonTBeShown')">
      {{ $t('project.applications.keepItOnYourServer') }}
    </BaseAlert>
    <template #footer>
      <BaseButton
        v-if="created"
        :label="$t('project.applications.iVeCopiedIt')"
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
