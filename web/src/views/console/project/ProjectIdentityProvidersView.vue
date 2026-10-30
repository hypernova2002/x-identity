<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import StatusBadge from '@/components/console/StatusBadge.vue'
import IdentityProviderForm from '@/components/project/IdentityProviderForm.vue'
import RoutePageHeader from '@/components/console/RoutePageHeader.vue'
import { useListView } from '@/composables/useListView'
import { useProjectContext } from '@/composables/useProjectContext'
import { useProviderEditor } from '@/composables/useProviderEditor'
import { projectAdminService } from '@/services/project'
import type { IdentityProviderKind } from '@/types/api'
import { identityProviderKindOptions, yesNoOptions } from '@/utils/options'

const { t } = useI18n()

const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const chooseOpen = ref(false)
const newKind = ref<IdentityProviderKind>('google')
const editor = useProviderEditor(() => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null))

const callbackUrl = computed(() => (project.value ? `${project.value.token_issuer}/auth/providers/callback` : ''))
const kindLabel = (kind: IdentityProviderKind) => identityProviderKindOptions.find((option) => option.value === kind)?.label ?? kind

const categories: Record<IdentityProviderKind, string> = {
  google: t('project.projectIdentityProviders.social'),
  apple: t('project.projectIdentityProviders.social'),
  oidc: t('project.projectIdentityProviders.openidConnect'),
  saml: t('project.projectIdentityProviders.enterpriseSaml'),
}

const columns: DataTableColumn[] = [
  { key: 'name', label: t('project.projectIdentityProviders.provider'), sortKey: 'name' },
  { key: 'kind', label: t('project.projectIdentityProviders.type'), sortKey: 'kind' },
  { key: 'identifier', label: t('project.projectIdentityProviders.identifier') },
  { key: 'enabled', label: t('project.projectIdentityProviders.status') },
]
const filters: DataTableFilter[] = [
  { type: 'select', key: 'kind_eq', label: t('project.projectIdentityProviders.type'), options: identityProviderKindOptions },
  { type: 'select', key: 'enabled_eq', label: t('project.projectIdentityProviders.enabled'), options: yesNoOptions },
]

const list = useListView((params) => projectAdminService.listIdentityProviders(accountUid.value, project.value!.uid, params), {
  defaultSort: 'created_at',
  storageKey: 'identity-providers',
  filterKeys: filters.map((filter) => filter.key),
  syncRoute: true,
})
const listState = list.state

function startAdding() {
  chooseOpen.value = false
  editor.start(null, newKind.value)
}

async function create() {
  const saved = await editor.save.run()
  if (saved && project.value) await router.push({ name: 'project-identity-provider', params: { projectUid: project.value.uid, providerUid: saved.uid } })
}

</script>

<template>
  <RoutePageHeader>
    <template v-if="access.admin" #actions>
      <BaseButton :label="$t('project.projectIdentityProviders.addIdentityProvider')" @click="chooseOpen = true" />
    </template>
  </RoutePageHeader>

  <BaseCard>
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div class="flex max-w-2xl flex-col gap-1 text-sm">
        <span class="font-medium">{{ $t('project.projectIdentityProviders.callbackUrlForGoogleApple') }}</span>
        <code class="font-mono text-xs break-all">{{ callbackUrl }}</code>
        <span class="text-xs text-text-muted">{{ $t('project.projectIdentityProviders.registerItAsTheRedirect') }}</span>
      </div>
    </div>
    <BaseAlert v-if="!access.admin" variant="info">{{ $t('project.projectIdentityProviders.onlyProjectAndAccountAdmins') }}</BaseAlert>
  </BaseCard>

  <BaseDataTable
    storage-key="identity-providers"
    v-model:state="listState"
    :caption="$t('project.projectIdentityProviders.identityProviders')"
    :search-placeholder="$t('project.projectIdentityProviders.searchIdentityProviders')"
    :search-label="$t('project.projectIdentityProviders.searchByName')"
    :columns="columns"
    :filters="filters"
    :rows="list.rows.value"
    :row-key="(provider) => provider.uid"
    :total="list.total.value"
    :per-page="list.perPage.value"
    :loading="list.loading.value"
    :error="list.error.value"
    :empty-message="$t('project.projectIdentityProviders.noIdentityProvidersYetEnd')"
    @reload="list.reload"
  >
    <template #cell-name="{ row }">
      <RouterLink
        :to="{ name: 'project-identity-provider', params: { projectUid: project?.uid, providerUid: row.uid } }"
        class="font-medium text-primary underline-offset-2 hover:underline"
      >
        {{ row.name }}
      </RouterLink>
      <span v-if="row.domains.length > 0" class="block text-xs text-text-muted">{{ $t('project.projectIdentityProviders.domains', { domains: row.domains.join(', ') }) }}</span>
    </template>
    <template #cell-kind="{ row }">
      {{ kindLabel(row.kind) }}
      <span class="block text-xs text-text-muted">{{ categories[row.kind] }}</span>
    </template>
    <template #cell-identifier="{ row }">
      <code class="font-mono text-xs break-all">{{ row.kind === 'saml' ? row.saml_idp_entity_id : row.client_id }}</code>
    </template>
    <template #cell-enabled="{ row }">
      <StatusBadge :tone="row.enabled ? 'success' : 'neutral'" :label="row.enabled ? $t('project.projectIdentityProviders.enabled') : $t('project.projectIdentityProviders.disabled')" />
    </template>
  </BaseDataTable>

  <i18n-t keypath="project.projectIdentityProviders.applicationsNote" tag="p" class="text-sm text-text-muted">
    <template #through><em>{{ $t('project.projectIdentityProviders.through') }}</em></template>
    <template #link><RouterLink :to="{ name: 'project-applications', params: { projectUid: project?.uid } }" class="font-medium text-primary underline">{{ $t('project.projectIdentityProviders.applications') }}</RouterLink></template>
  </i18n-t>

  <BaseDialog v-model:visible="chooseOpen" :title="$t('project.projectIdentityProviders.addAnIdentityProvider')">
    <BaseSelect v-model="newKind" :label="$t('project.projectIdentityProviders.provider')" :options="identityProviderKindOptions" />
    <template #footer>
      <BaseButton :label="$t('project.projectIdentityProviders.cancel')" variant="secondary" @click="chooseOpen = false" />
      <BaseButton :label="$t('project.projectIdentityProviders.continue')" @click="startAdding" />
    </template>
  </BaseDialog>

  <BaseDialog v-model:visible="editor.open.value" :title="$t('project.projectIdentityProviders.add', { kind: kindLabel(editor.draft.value.kind) })">
    <IdentityProviderForm
      v-model="editor.draft.value"
      form-id="identity-provider-form"
      :existing="null"
      :error="editor.save.error.value"
      :import-error="editor.importMetadata.error.value"
      :importing="editor.importMetadata.loading.value"
      @submit="create"
      @import-metadata="(source) => editor.importMetadata.run(source)"
    />
    <template #footer>
      <BaseButton :label="$t('project.projectIdentityProviders.cancel')" variant="secondary" @click="editor.open.value = false" />
      <BaseButton :label="$t('project.projectIdentityProviders.addProvider')" type="submit" form="identity-provider-form" :loading="editor.save.loading.value" />
    </template>
  </BaseDialog>
</template>
