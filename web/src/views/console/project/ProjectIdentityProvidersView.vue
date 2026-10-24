<script setup lang="ts">
import { computed, ref } from 'vue'
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
import { useListView } from '@/composables/useListView'
import { useProjectContext } from '@/composables/useProjectContext'
import { useProviderEditor } from '@/composables/useProviderEditor'
import { projectAdminService } from '@/services/project'
import type { IdentityProviderKind } from '@/types/api'
import { identityProviderKindOptions, yesNoOptions } from '@/utils/options'

const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const chooseOpen = ref(false)
const newKind = ref<IdentityProviderKind>('google')
const editor = useProviderEditor(() => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null))

const callbackUrl = computed(() => (project.value ? `${project.value.token_issuer}/auth/providers/callback` : ''))
const kindLabel = (kind: IdentityProviderKind) => identityProviderKindOptions.find((option) => option.value === kind)?.label ?? kind

const categories: Record<IdentityProviderKind, string> = {
  google: 'Social',
  apple: 'Social',
  oidc: 'OpenID Connect',
  saml: 'Enterprise SAML',
}

const columns: DataTableColumn[] = [
  { key: 'name', label: 'Provider', sortKey: 'name' },
  { key: 'kind', label: 'Type', sortKey: 'kind' },
  { key: 'identifier', label: 'Identifier' },
  { key: 'enabled', label: 'Status' },
]
const filters: DataTableFilter[] = [
  { type: 'select', key: 'kind_eq', label: 'Type', options: identityProviderKindOptions },
  { type: 'select', key: 'enabled_eq', label: 'Enabled', options: yesNoOptions },
]

const list = useListView((params) => projectAdminService.listIdentityProviders(accountUid.value, project.value!.uid, params), {
  defaultSort: 'created_at',
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
  <BaseCard>
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div class="flex max-w-2xl flex-col gap-1 text-sm">
        <span class="font-medium">Callback URL for Google, Apple and OpenID Connect providers</span>
        <code class="font-mono text-xs break-all">{{ callbackUrl }}</code>
        <span class="text-xs text-text-muted">Register it as the redirect URI in the provider's app settings. SAML providers each have their own details.</span>
      </div>
      <BaseButton v-if="access.admin" label="Add identity provider" @click="chooseOpen = true" />
    </div>
    <BaseAlert v-if="!access.admin" variant="info">Only project and account admins can change identity providers.</BaseAlert>
  </BaseCard>

  <BaseDataTable
    v-model:state="listState"
    caption="Identity providers"
    search-label="Search by name"
    :columns="columns"
    :filters="filters"
    :rows="list.rows.value"
    :row-key="(provider) => provider.uid"
    :total="list.total.value"
    :per-page="list.perPage.value"
    :loading="list.loading.value"
    :error="list.error.value"
    empty-message="No identity providers yet. End users sign in with a password or email code."
    @retry="list.reload"
  >
    <template #cell-name="{ row }">
      <RouterLink
        :to="{ name: 'project-identity-provider', params: { projectUid: project?.uid, providerUid: row.uid } }"
        class="font-medium text-primary underline-offset-2 hover:underline"
      >
        {{ row.name }}
      </RouterLink>
      <span v-if="row.domains.length > 0" class="block text-xs text-text-muted">Domains: {{ row.domains.join(', ') }}</span>
    </template>
    <template #cell-kind="{ row }">
      {{ kindLabel(row.kind) }}
      <span class="block text-xs text-text-muted">{{ categories[row.kind] }}</span>
    </template>
    <template #cell-identifier="{ row }">
      <code class="font-mono text-xs break-all">{{ row.kind === 'saml' ? row.saml_idp_entity_id : row.client_id }}</code>
    </template>
    <template #cell-enabled="{ row }">
      <StatusBadge :tone="row.enabled ? 'success' : 'neutral'" :label="row.enabled ? 'Enabled' : 'Disabled'" />
    </template>
  </BaseDataTable>

  <p class="text-sm text-text-muted">
    Applications that sign users in <em>through</em> this project are under
    <RouterLink :to="{ name: 'project-applications', params: { projectUid: project?.uid } }" class="font-medium text-primary underline">Applications</RouterLink>.
  </p>

  <BaseDialog v-model:visible="chooseOpen" title="Add an identity provider">
    <BaseSelect v-model="newKind" label="Provider" :options="identityProviderKindOptions" />
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="chooseOpen = false" />
      <BaseButton label="Continue" @click="startAdding" />
    </template>
  </BaseDialog>

  <BaseDialog v-model:visible="editor.open.value" :title="`Add ${kindLabel(editor.draft.value.kind)}`">
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
      <BaseButton label="Cancel" variant="secondary" @click="editor.open.value = false" />
      <BaseButton label="Add provider" type="submit" form="identity-provider-form" :loading="editor.save.loading.value" />
    </template>
  </BaseDialog>
</template>
