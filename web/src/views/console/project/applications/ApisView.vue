<script setup lang="ts">
import { ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import type { DataTableColumn } from '@/components/base/types'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import RoutePageHeader from '@/components/console/RoutePageHeader.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useListView } from '@/composables/useListView'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { ApiResource, ApiScope } from '@/types/api'
import { formatDuration } from '@/utils/format'

const { accountUid, project, access } = useProjectContext()

const columns: DataTableColumn[] = [
  { key: 'name', label: 'API', sortKey: 'name' },
  { key: 'scopes', label: 'Scopes' },
  { key: 'app_count', label: 'Apps with access' },
  { key: 'ttl', label: 'Token lifetime' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const list = useListView((params) => projectAdminService.listApis(accountUid.value, project.value!.uid, params), {
  defaultSort: 'name',
  storageKey: 'apis',
  syncRoute: true,
})
const listState = list.state

const editing = ref<ApiResource | null>(null)
const formOpen = ref(false)
const name = ref('')
const identifier = ref('')
const ttl = ref('')
const scopes = ref<ApiScope[]>([])
const pendingDelete = ref<ApiResource | null>(null)

function openForm(api: ApiResource | null) {
  editing.value = api
  name.value = api?.name ?? ''
  identifier.value = api?.identifier ?? ''
  ttl.value = api?.access_token_ttl_seconds?.toString() ?? ''
  scopes.value = api ? api.scopes.map((scope) => ({ ...scope })) : [{ name: '', description: null }]
  save.error.value = null
  formOpen.value = true
}

const save = useAsyncAction(async () => {
  if (!project.value) return
  const input = {
    name: name.value,
    scopes: scopes.value.filter((scope) => scope.name.trim()).map((scope) => ({ name: scope.name.trim(), description: scope.description?.trim() || null })),
    access_token_ttl_seconds: ttl.value.trim() ? Number(ttl.value) : null,
  }
  if (editing.value) await projectAdminService.updateApi(accountUid.value, project.value.uid, editing.value.uid, input)
  else await projectAdminService.createApi(accountUid.value, project.value.uid, { ...input, identifier: identifier.value.trim() })
  formOpen.value = false
  await list.reload()
})

const destroy = useAsyncAction(async (api: ApiResource) => {
  if (!project.value) return
  await projectAdminService.deleteApi(accountUid.value, project.value.uid, api.uid)
  pendingDelete.value = null
  await list.reload()
})
</script>

<template>
  <RoutePageHeader>
    <template v-if="access.developer" #actions>
      <BaseButton label="Add API" @click="openForm(null)" />
    </template>
  </RoutePageHeader>

  <BaseCard>
    <BaseDataTable
      storage-key="apis"
      v-model:state="listState"
      caption="APIs"
      search-placeholder="Search APIs…"
      search-label="Search by name or identifier"
      :columns="columns"
      :rows="list.rows.value"
      :row-key="(api) => api.uid"
      :total="list.total.value"
      :per-page="list.perPage.value"
      :loading="list.loading.value"
      :error="list.error.value"
      empty-message="No APIs yet. Add one for each of your services that machine-to-machine apps call."
      @reload="list.reload"
    >
      <template #cell-name="{ row }">
        <span class="font-medium">{{ row.name }}</span>
        <code class="block font-mono text-xs break-all text-text-muted">{{ row.identifier }}</code>
      </template>
      <template #cell-scopes="{ row }">
        <span v-if="row.scopes.length === 0" class="text-text-muted">None</span>
        <span v-else class="flex flex-wrap gap-1">
          <code v-for="scope in row.scopes" :key="scope.name" class="rounded-sm bg-bg-subtle px-1 font-mono text-xs">{{ scope.name }}</code>
        </span>
      </template>
      <template #cell-ttl="{ row }">
        <span class="text-xs">{{ row.access_token_ttl_seconds ? formatDuration(row.access_token_ttl_seconds) : 'Project default' }}</span>
      </template>
      <template #cell-actions="{ row }">
        <div v-if="access.developer" class="flex justify-end gap-2">
          <BaseButton label="Edit" variant="secondary" size="sm" @click="openForm(row)" />
          <BaseButton label="Delete" variant="ghost" size="sm" @click="pendingDelete = row" />
        </div>
      </template>
    </BaseDataTable>
  </BaseCard>

  <p class="text-sm text-text-muted">
    Machine-to-machine apps request tokens for an API by its identifier, with the client credentials grant. Your API checks the token's
    signature with the project's published keys, and its <code class="font-mono text-xs">aud</code> and
    <code class="font-mono text-xs">scope</code> claims.
  </p>

  <BaseDialog v-model:visible="formOpen" :title="editing ? `Edit ${editing.name}` : 'Add API'">
    <form id="api-form" class="flex flex-col gap-4" novalidate @submit.prevent="save.run()">
      <BaseAlert v-if="save.error.value && save.error.value.details.length === 0" variant="danger">{{ save.error.value.message }}</BaseAlert>
      <BaseInput v-model="name" label="Name" required hint="For example Orders API." :error="save.error.value?.fieldError('name')" />
      <BaseInput
        v-if="!editing"
        v-model="identifier"
        label="Identifier"
        required
        hint="The tokens' audience (aud), usually the API's URL, e.g. https://orders.example.com. It can't be changed later."
        :error="save.error.value?.fieldError('identifier')"
      />
      <p v-else class="text-sm">
        Identifier: <code class="font-mono text-xs break-all">{{ editing?.identifier }}</code>
      </p>

      <fieldset class="flex flex-col gap-3">
        <legend class="mb-1 text-sm font-semibold">Scopes</legend>
        <p class="text-xs text-text-muted">What apps can be allowed to do, e.g. orders:read. Removing a scope takes it out of every app's access.</p>
        <div v-for="(scope, index) in scopes" :key="index" class="flex flex-wrap items-end gap-2">
          <div class="min-w-36 flex-1"><BaseInput v-model="scope.name" :label="`Scope ${index + 1}`" /></div>
          <div class="min-w-36 flex-1">
            <BaseInput :model-value="scope.description ?? ''" label="Description" @update:model-value="(value: string) => (scope.description = value)" />
          </div>
          <BaseButton label="Remove" variant="ghost" size="sm" @click="scopes.splice(index, 1)" />
        </div>
        <p v-if="save.error.value?.fieldError('scopes')" class="text-xs font-medium text-danger">Error: {{ save.error.value.fieldError('scopes') }}</p>
        <BaseButton label="Add scope" variant="secondary" size="sm" class="self-start" @click="scopes.push({ name: '', description: null })" />
      </fieldset>

      <BaseInput
        v-model="ttl"
        label="Token lifetime (seconds)"
        type="number"
        hint="300–3600. Leave empty to use the project's access token lifetime."
        :error="save.error.value?.fieldError('access_token_ttl_seconds')"
      />
    </form>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="formOpen = false" />
      <BaseButton :label="editing ? 'Save' : 'Add API'" type="submit" form="api-form" :loading="save.loading.value" />
    </template>
  </BaseDialog>

  <ConfirmDialog
    :visible="pendingDelete !== null"
    title="Delete API?"
    confirm-label="Delete API"
    danger
    :loading="destroy.loading.value"
    :error="destroy.error.value"
    @update:visible="(open: boolean) => !open && (pendingDelete = null)"
    @confirm="pendingDelete && destroy.run(pendingDelete)"
  >
    <p>
      Apps lose access to <strong>{{ pendingDelete?.name }}</strong> and can't get new tokens for it. Tokens they already have keep working
      until they expire.
    </p>
  </ConfirmDialog>
</template>
