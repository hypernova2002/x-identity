<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'

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

const { t } = useI18n()

const { accountUid, project, access } = useProjectContext()

const columns: DataTableColumn[] = [
  { key: 'name', label: t('project.apis.api'), sortKey: 'name' },
  { key: 'scopes', label: t('project.apis.scopes') },
  { key: 'app_count', label: t('project.apis.appsWithAccess') },
  { key: 'ttl', label: t('project.apis.tokenLifetime') },
  { key: 'actions', label: t('project.apis.actions'), srOnly: true },
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
      <BaseButton :label="$t('project.apis.addApi')" @click="openForm(null)" />
    </template>
  </RoutePageHeader>

  <BaseCard>
    <BaseDataTable
      storage-key="apis"
      v-model:state="listState"
      :caption="$t('project.apis.apis')"
      :search-placeholder="$t('project.apis.searchApis')"
      :search-label="$t('project.apis.searchByNameOrIdentifier')"
      :columns="columns"
      :rows="list.rows.value"
      :row-key="(api) => api.uid"
      :total="list.total.value"
      :per-page="list.perPage.value"
      :loading="list.loading.value"
      :error="list.error.value"
      :empty-message="$t('project.apis.noApisYetAddOne')"
      @reload="list.reload"
    >
      <template #cell-name="{ row }">
        <span class="font-medium">{{ row.name }}</span>
        <code class="block font-mono text-xs break-all text-text-muted">{{ row.identifier }}</code>
      </template>
      <template #cell-scopes="{ row }">
        <span v-if="row.scopes.length === 0" class="text-text-muted">{{ $t('project.apis.none') }}</span>
        <span v-else class="flex flex-wrap gap-1">
          <code v-for="scope in row.scopes" :key="scope.name" class="rounded-sm bg-bg-subtle px-1 font-mono text-xs">{{ scope.name }}</code>
        </span>
      </template>
      <template #cell-ttl="{ row }">
        <span class="text-xs">{{ row.access_token_ttl_seconds ? formatDuration(row.access_token_ttl_seconds) : $t('project.apis.projectDefault') }}</span>
      </template>
      <template #cell-actions="{ row }">
        <div v-if="access.developer" class="flex justify-end gap-2">
          <BaseButton :label="$t('project.apis.edit')" variant="secondary" size="sm" @click="openForm(row)" />
          <BaseButton :label="$t('project.apis.delete')" variant="ghost" size="sm" @click="pendingDelete = row" />
        </div>
      </template>
    </BaseDataTable>
  </BaseCard>

  <i18n-t keypath="project.apis.tokenClaimsNote" tag="p" class="text-sm text-text-muted">
    <template #aud><code class="font-mono text-xs">{{ $t('project.apis.aud') }}</code></template>
    <template #scope><code class="font-mono text-xs">{{ $t('project.apis.scope') }}</code></template>
  </i18n-t>

  <BaseDialog v-model:visible="formOpen" :title="editing ? $t('project.apis.edit2', { name: editing.name }) : $t('project.apis.addApi')">
    <form id="api-form" class="flex flex-col gap-4" novalidate @submit.prevent="save.run()">
      <BaseAlert v-if="save.error.value && save.error.value.details.length === 0" variant="danger">{{ save.error.value.message }}</BaseAlert>
      <BaseInput v-model="name" :label="$t('project.apis.name')" required :hint="$t('project.apis.forExampleOrdersApi')" :error="save.error.value?.fieldError('name')" />
      <BaseInput
        v-if="!editing"
        v-model="identifier"
        :label="$t('project.apis.identifier')"
        required
        :hint="$t('project.apis.theTokensAudienceAudUsually')"
        :error="save.error.value?.fieldError('identifier')"
      />
      <i18n-t keypath="project.apis.identifierLine" tag="p" v-else class="text-sm">
        <template #identifier><code class="font-mono text-xs break-all">{{ editing?.identifier }}</code></template>
      </i18n-t>

      <fieldset class="flex flex-col gap-3">
        <legend class="mb-1 text-sm font-semibold">{{ $t('project.apis.scopes') }}</legend>
        <p class="text-xs text-text-muted">{{ $t('project.apis.whatAppsCanBeAllowed') }}</p>
        <div v-for="(scope, index) in scopes" :key="index" class="flex flex-wrap items-end gap-2">
          <div class="min-w-36 flex-1"><BaseInput v-model="scope.name" :label="$t('project.apis.scope2', { index: index + 1 })" /></div>
          <div class="min-w-36 flex-1">
            <BaseInput :model-value="scope.description ?? ''" :label="$t('project.apis.description')" @update:model-value="(value: string) => (scope.description = value)" />
          </div>
          <BaseButton :label="$t('project.apis.remove')" variant="ghost" size="sm" @click="scopes.splice(index, 1)" />
        </div>
        <p v-if="save.error.value?.fieldError('scopes')" class="text-xs font-medium text-danger">{{ $t('base.field.error', { message: save.error.value.fieldError('scopes') }) }}</p>
        <BaseButton :label="$t('project.apis.addScope')" variant="secondary" size="sm" class="self-start" @click="scopes.push({ name: '', description: null })" />
      </fieldset>

      <BaseInput
        v-model="ttl"
        :label="$t('project.apis.tokenLifetimeSeconds')"
        type="number"
        :hint="$t('project.apis.leaveEmptyToUseThe')"
        :error="save.error.value?.fieldError('access_token_ttl_seconds')"
      />
    </form>
    <template #footer>
      <BaseButton :label="$t('project.apis.cancel')" variant="secondary" @click="formOpen = false" />
      <BaseButton :label="editing ? $t('project.apis.save') : $t('project.apis.addApi')" type="submit" form="api-form" :loading="save.loading.value" />
    </template>
  </BaseDialog>

  <ConfirmDialog
    :visible="pendingDelete !== null"
    :title="$t('project.apis.deleteApi')"
    :confirm-label="$t('project.apis.deleteApi2')"
    danger
    :loading="destroy.loading.value"
    :error="destroy.error.value"
    @update:visible="(open: boolean) => !open && (pendingDelete = null)"
    @confirm="pendingDelete && destroy.run(pendingDelete)"
  >
    <i18n-t keypath="project.apis.deleteDescription" tag="p">
      <template #name><strong>{{ pendingDelete?.name }}</strong></template>
    </i18n-t>
  </ConfirmDialog>
</template>
