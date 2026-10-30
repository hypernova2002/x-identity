<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseSearchSelect from '@/components/base/BaseSearchSelect.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import { useAppClient } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { useProjectLookups } from '@/composables/useProjectLookups'
import type { LookupPage } from '@/services/list'
import { projectAdminService } from '@/services/project'
import type { ApiGrant, ApiResource } from '@/types/api'

const { accountUid, project, access } = useProjectContext()
const { record: client } = useAppClient()
const lookups = useProjectLookups()

const grants = ref<ApiGrant[]>([])
/** Each granted API, for its scope list. */
const apis = ref<Record<string, ApiResource>>({})
const drafts = ref<Record<string, string[]>>({})
const newApiUid = ref('')
const newApi = ref<ApiResource | null>(null)
const newScopes = ref<string[]>([])
const pendingRevoke = ref<ApiGrant | null>(null)

const ids = () => [accountUid.value, project.value!.uid, client.value.uid] as const

const load = useAsyncAction(async () => {
  if (!project.value) return
  grants.value = await projectAdminService.listApiGrants(...ids())
  const loaded = await Promise.all(grants.value.map((grant) => projectAdminService.getApi(accountUid.value, project.value!.uid, grant.api_uid)))
  apis.value = Object.fromEntries(loaded.map((api) => [api.uid, api]))
  drafts.value = Object.fromEntries(grants.value.map((grant) => [grant.uid, [...grant.scopes]]))
})

/** APIs the app doesn't have access to yet. */
async function searchUngrantedApis(term: string): Promise<LookupPage> {
  const page = await lookups.searchApis(term)
  const items = page.items.filter((option) => !grants.value.some((grant) => grant.api_uid === option.value))
  return { items, total: page.total - (page.items.length - items.length) }
}

const pickApi = useAsyncAction(async (apiUid: string) => {
  newApi.value = null
  newScopes.value = []
  if (!apiUid || !project.value) return
  newApi.value = await projectAdminService.getApi(accountUid.value, project.value.uid, apiUid)
})

const grant = useAsyncAction(async () => {
  if (!newApi.value) return
  await projectAdminService.grantApi(...ids(), newApi.value.uid, newScopes.value)
  newApiUid.value = ''
  newApi.value = null
  newScopes.value = []
  await load.run()
})

const saveScopes = useAsyncAction(async (target: ApiGrant) => {
  await projectAdminService.updateApiGrant(...ids(), target.uid, drafts.value[target.uid] ?? [])
  await load.run()
})

const revoke = useAsyncAction(async (target: ApiGrant) => {
  await projectAdminService.revokeApiGrant(...ids(), target.uid)
  pendingRevoke.value = null
  await load.run()
})

function toggle(list: string[], scope: string, on: boolean) {
  const index = list.indexOf(scope)
  if (on && index === -1) list.push(scope)
  if (!on && index !== -1) list.splice(index, 1)
}

const changed = (target: ApiGrant) => [...(drafts.value[target.uid] ?? [])].sort().join(' ') !== [...target.scopes].sort().join(' ')

onMounted(() => load.run())
</script>

<template>
  <BaseCard
    :title="$t('project.appClientApiAccess.apiAccess')"
    :description="$t('project.appClientApiAccess.theApisThisAppCan')"
  >
    <BaseAlert v-if="load.error.value" variant="danger">{{ $t('project.appClientApiAccess.loadFailed', { message: load.error.value.message }) }}</BaseAlert>
    <p v-else-if="load.loading.value && grants.length === 0" class="text-sm text-text-muted" role="status">{{ $t('project.appClientApiAccess.loading') }}</p>
    <p v-else-if="grants.length === 0" class="text-sm text-text-muted">{{ $t('project.appClientApiAccess.thisAppCanTGet') }}</p>

    <ul v-else class="flex flex-col divide-y divide-border">
      <li v-for="item in grants" :key="item.uid" class="flex flex-col gap-3 py-3">
        <div class="flex flex-wrap items-baseline justify-between gap-2">
          <span>
            <span class="font-medium">{{ item.api_name }}</span>
            <code class="block font-mono text-xs break-all text-text-muted">{{ item.api_identifier }}</code>
          </span>
          <BaseButton v-if="access.developer" :label="$t('project.appClientApiAccess.removeAccess')" variant="ghost" size="sm" @click="pendingRevoke = item" />
        </div>
        <p v-if="(apis[item.api_uid]?.scopes.length ?? 0) === 0" class="text-xs text-text-muted">{{ $t('project.appClientApiAccess.theApiDefinesNoScopes') }}</p>
        <div v-else class="flex flex-wrap gap-x-6 gap-y-2">
          <BaseCheckbox
            v-for="scope in apis[item.api_uid]?.scopes ?? []"
            :key="scope.name"
            :model-value="drafts[item.uid]?.includes(scope.name) ?? false"
            :label="scope.name"
            :hint="scope.description ?? undefined"
            :disabled="!access.developer"
            @update:model-value="(on: boolean) => toggle(drafts[item.uid] ?? [], scope.name, on)"
          />
        </div>
        <BaseButton
          v-if="access.developer && changed(item)"
          :label="$t('project.appClientApiAccess.saveScopes')"
          variant="secondary"
          size="sm"
          class="self-start"
          :loading="saveScopes.loading.value"
          @click="saveScopes.run(item)"
        />
      </li>
    </ul>
    <BaseAlert v-if="saveScopes.error.value" variant="danger">{{ saveScopes.error.value.message }}</BaseAlert>
  </BaseCard>

  <BaseCard v-if="access.developer" :title="$t('project.appClientApiAccess.giveAccessToAnApi')">
    <BaseSearchSelect
      v-model="newApiUid"
      :label="$t('project.appClientApiAccess.api')"
      :search="searchUngrantedApis"
      :see-all="lookups.allApis.value"
      @update:model-value="(uid: string) => pickApi.run(uid)"
    />
    <i18n-t keypath="project.appClientApiAccess.apisDefinedOn" tag="p" class="text-xs text-text-muted">
      <template #link><RouterLink :to="lookups.allApis.value" class="font-medium text-primary underline">{{ $t('project.appClientApiAccess.apis') }}</RouterLink></template>
    </i18n-t>
    <template v-if="newApi">
      <p v-if="newApi.scopes.length === 0" class="text-xs text-text-muted">{{ $t('project.appClientApiAccess.thisApiDefinesNoScopes') }}</p>
      <div v-else class="flex flex-wrap gap-x-6 gap-y-2">
        <BaseCheckbox
          v-for="scope in newApi.scopes"
          :key="scope.name"
          :model-value="newScopes.includes(scope.name)"
          :label="scope.name"
          :hint="scope.description ?? undefined"
          @update:model-value="(on: boolean) => toggle(newScopes, scope.name, on)"
        />
      </div>
      <BaseAlert v-if="grant.error.value" variant="danger">{{ grant.error.value.message }}</BaseAlert>
      <BaseButton :label="$t('project.appClientApiAccess.giveAccess')" class="self-start" :loading="grant.loading.value" @click="grant.run()" />
    </template>
  </BaseCard>

  <ConfirmDialog
    :visible="pendingRevoke !== null"
    :title="$t('project.appClientApiAccess.removeAccessToThisApi')"
    :confirm-label="$t('project.appClientApiAccess.removeAccess')"
    danger
    :loading="revoke.loading.value"
    :error="revoke.error.value"
    @update:visible="(open: boolean) => !open && (pendingRevoke = null)"
    @confirm="pendingRevoke && revoke.run(pendingRevoke)"
  >
    <i18n-t keypath="project.appClientApiAccess.revokeDescription" tag="p">
      <template #client><strong>{{ client.name }}</strong></template>
      <template #api><strong>{{ pendingRevoke?.api_name }}</strong></template>
    </i18n-t>
  </ConfirmDialog>
</template>
