<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import IdentityProviderForm from '@/components/project/IdentityProviderForm.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { useProviderEditor } from '@/composables/useProviderEditor'
import { projectAdminService } from '@/services/project'
import type { Group, IdentityProvider, IdentityProviderKind } from '@/types/api'
import { identityProviderKindOptions } from '@/utils/options'

const router = useRouter()
const { accountUid, project, access } = useProjectContext()

const providers = ref<IdentityProvider[]>([])
const groups = ref<Group[]>([])
const chooseOpen = ref(false)
const newKind = ref<IdentityProviderKind>('google')
const editor = useProviderEditor(() => (project.value ? { accountUid: accountUid.value, projectUid: project.value.uid } : null))

const callbackUrl = computed(() => (project.value ? `${project.value.token_issuer}/auth/providers/callback` : ''))
const kindLabel = (kind: IdentityProviderKind) => identityProviderKindOptions.find((option) => option.value === kind)?.label ?? kind

const sections = computed(() => [
  {
    key: 'social',
    title: 'Social identity providers',
    description: 'Google and Apple accounts.',
    rows: providers.value.filter((provider) => provider.kind === 'google' || provider.kind === 'apple'),
  },
  {
    key: 'oidc',
    title: 'OpenID Connect providers',
    description: 'Any other provider that supports OpenID Connect discovery.',
    rows: providers.value.filter((provider) => provider.kind === 'oidc'),
  },
  {
    key: 'saml',
    title: 'Enterprise SAML providers',
    description: 'A company\'s own identity provider (Okta, Entra ID, ADFS…), trusted for its email domains.',
    rows: providers.value.filter((provider) => provider.kind === 'saml'),
  },
])

const columns = [
  { key: 'name', label: 'Provider' },
  { key: 'identifier', label: 'Identifier' },
  { key: 'enabled', label: 'Status' },
]

const load = useAsyncAction(async () => {
  if (!project.value) return
  const [loadedProviders, loadedGroups] = await Promise.all([
    projectAdminService.listIdentityProviders(accountUid.value, project.value.uid),
    projectAdminService.listGroups(accountUid.value, project.value.uid),
  ])
  providers.value = loadedProviders.items
  groups.value = loadedGroups.items
})

function startAdding() {
  chooseOpen.value = false
  editor.start(null, newKind.value)
}

async function create() {
  const saved = await editor.save.run()
  if (saved && project.value) await router.push({ name: 'project-identity-provider', params: { projectUid: project.value.uid, providerUid: saved.uid } })
}

onMounted(() => load.run())
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
    <BaseAlert v-if="load.error.value" variant="danger">We couldn't load identity providers. {{ load.error.value.message }}</BaseAlert>
  </BaseCard>

  <BaseCard v-for="section in sections" :key="section.key" :title="section.title" :description="section.description">
    <BaseTable
      :caption="section.title"
      :columns="columns"
      :rows="section.rows"
      :row-key="(provider) => provider.uid"
      :loading="load.loading.value"
      :empty-message="`No ${section.title.toLowerCase()} yet.`"
    >
      <template #cell-name="{ row }">
        <RouterLink
          :to="{ name: 'project-identity-provider', params: { projectUid: project?.uid, providerUid: row.uid } }"
          class="font-medium text-primary underline-offset-2 hover:underline"
        >
          {{ row.name }}
        </RouterLink>
        <span class="block text-xs text-text-muted">{{ kindLabel(row.kind) }}</span>
        <span v-if="row.domains.length > 0" class="block text-xs text-text-muted">Domains: {{ row.domains.join(', ') }}</span>
      </template>
      <template #cell-identifier="{ row }">
        <code class="font-mono text-xs break-all">{{ row.kind === 'saml' ? row.saml_idp_entity_id : row.client_id }}</code>
      </template>
      <template #cell-enabled="{ row }">
        <StatusBadge :tone="row.enabled ? 'success' : 'neutral'" :label="row.enabled ? 'Enabled' : 'Disabled'" />
      </template>
    </BaseTable>
  </BaseCard>

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
      :groups="groups"
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
