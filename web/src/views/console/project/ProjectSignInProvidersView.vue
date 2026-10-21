<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import IdentityProviderForm from '@/components/project/IdentityProviderForm.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { IdentityProvider, IdentityProviderKind } from '@/types/api'
import { emptyProviderDraft, providerDraftFrom, providerInputFrom, type IdentityProviderDraft } from '@/utils/identityProviders'
import { identityProviderKindOptions } from '@/utils/options'

const { accountUid, project, access } = useProjectContext()

const providers = ref<IdentityProvider[]>([])
const addOpen = ref(false)
const newKind = ref<IdentityProviderKind>('google')
const editing = ref<IdentityProvider | null>(null)
const formOpen = ref(false)
const draft = ref<IdentityProviderDraft>(emptyProviderDraft('google'))
const pendingDelete = ref<IdentityProvider | null>(null)
const notice = ref<string | null>(null)

const callbackUrl = computed(() => (project.value ? `${project.value.token_issuer}/auth/providers/callback` : ''))
const kindLabel = (kind: IdentityProviderKind) => identityProviderKindOptions.find((option) => option.value === kind)?.label ?? kind
const formTitle = computed(() => (editing.value ? `Edit ${editing.value.name}` : `Add ${kindLabel(draft.value.kind)}`))

const columns = [
  { key: 'name', label: 'Provider' },
  { key: 'client_id', label: 'Client ID' },
  { key: 'enabled', label: 'Status' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const load = useAsyncAction(async () => {
  if (!project.value) return
  providers.value = (await projectAdminService.listIdentityProviders(accountUid.value, project.value.uid)).items
})

function replace(updated: IdentityProvider) {
  const exists = providers.value.some((existing) => existing.uid === updated.uid)
  providers.value = exists ? providers.value.map((existing) => (existing.uid === updated.uid ? updated : existing)) : [...providers.value, updated]
}

const save = useAsyncAction(async () => {
  if (!project.value) return
  const input = providerInputFrom(draft.value)
  const saved = editing.value
    ? await projectAdminService.updateIdentityProvider(accountUid.value, project.value.uid, editing.value.uid, input)
    : await projectAdminService.createIdentityProvider(accountUid.value, project.value.uid, draft.value.kind, input)
  replace(saved)
  notice.value = editing.value ? `${saved.name} was saved.` : `${saved.name} was added. End users can sign in with it now.`
  formOpen.value = false
})

function openForm(provider: IdentityProvider | null) {
  editing.value = provider
  draft.value = provider ? providerDraftFrom(provider) : emptyProviderDraft(newKind.value)
  save.error.value = null
  addOpen.value = false
  formOpen.value = true
}

const providerAction = useAsyncAction(async (provider: IdentityProvider, action: 'toggle' | 'delete') => {
  if (!project.value) return
  notice.value = null
  if (action === 'delete') {
    await projectAdminService.deleteIdentityProvider(accountUid.value, project.value.uid, provider.uid)
    providers.value = providers.value.filter((existing) => existing.uid !== provider.uid)
    pendingDelete.value = null
    notice.value = `${provider.name} was removed.`
    return
  }

  replace(await projectAdminService.updateIdentityProvider(accountUid.value, project.value.uid, provider.uid, { enabled: !provider.enabled }))
})

onMounted(() => load.run())
</script>

<template>
  <BaseCard
    title="Sign-in providers"
    description="Let end users sign in with Google, Apple or another OpenID Connect provider instead of a password."
  >
    <template v-if="access.admin" #footer>
      <BaseButton label="Add provider" @click="addOpen = true" />
    </template>

    <div class="flex flex-col gap-1 text-sm">
      <span class="font-medium">Callback URL</span>
      <code class="font-mono text-xs break-all">{{ callbackUrl }}</code>
      <span class="text-xs text-text-muted">
        Register this as the redirect URI in each provider's app settings. Your apps' own redirect URIs go on their app clients.
      </span>
    </div>

    <BaseAlert v-if="!access.admin" variant="info">Only project and account admins can change sign-in providers.</BaseAlert>
    <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>
    <BaseAlert v-if="load.error.value" variant="danger">We couldn't load sign-in providers. {{ load.error.value.message }}</BaseAlert>
    <BaseAlert v-if="providerAction.error.value" variant="danger">{{ providerAction.error.value.message }}</BaseAlert>

    <BaseTable
      caption="Sign-in providers"
      :columns="columns"
      :rows="providers"
      :row-key="(provider) => provider.uid"
      :loading="load.loading.value"
      empty-message="No sign-in providers yet. End users sign in with email and password only."
    >
      <template #cell-name="{ row }">
        <span class="font-medium">{{ row.name }}</span>
        <span class="block text-xs text-text-muted">{{ kindLabel(row.kind) }}{{ row.kind === 'oidc' && row.issuer ? ` · ${row.issuer}` : '' }}</span>
      </template>
      <template #cell-client_id="{ row }">
        <code class="font-mono text-xs break-all">{{ row.client_id }}</code>
        <span v-if="row.additional_audiences.length > 0" class="block text-xs text-text-muted">
          + {{ row.additional_audiences.length }} native app {{ row.additional_audiences.length === 1 ? 'client' : 'clients' }}
        </span>
      </template>
      <template #cell-enabled="{ row }">
        <span :class="row.enabled ? 'text-success' : 'text-text-muted'" class="font-medium">
          {{ row.enabled ? '● Enabled' : '○ Disabled' }}
        </span>
      </template>
      <template #cell-actions="{ row }">
        <div v-if="access.admin" class="flex flex-wrap justify-end gap-2">
          <BaseButton label="Edit" variant="secondary" size="sm" :disabled="providerAction.loading.value" @click="openForm(row)" />
          <BaseButton
            :label="row.enabled ? 'Disable' : 'Enable'"
            variant="secondary"
            size="sm"
            :disabled="providerAction.loading.value"
            @click="providerAction.run(row, 'toggle')"
          />
          <BaseButton label="Remove" variant="ghost" size="sm" :disabled="providerAction.loading.value" @click="pendingDelete = row" />
        </div>
      </template>
    </BaseTable>
  </BaseCard>

  <BaseDialog v-model:visible="addOpen" title="Add a sign-in provider">
    <BaseSelect v-model="newKind" label="Provider" :options="identityProviderKindOptions" />
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="addOpen = false" />
      <BaseButton label="Continue" @click="openForm(null)" />
    </template>
  </BaseDialog>

  <BaseDialog v-model:visible="formOpen" :title="formTitle">
    <IdentityProviderForm v-model="draft" form-id="identity-provider-form" :existing="editing" :error="save.error.value" @submit="save.run()" />
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="formOpen = false" />
      <BaseButton :label="editing ? 'Save' : 'Add provider'" type="submit" form="identity-provider-form" :loading="save.loading.value" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="pendingDelete !== null" title="Remove sign-in provider?" @update:visible="(open: boolean) => !open && (pendingDelete = null)">
    <p class="text-sm">
      End users will no longer be able to sign in with <strong>{{ pendingDelete?.name }}</strong>, and their links to it are removed.
      Users without a password will need to reset theirs to sign in again. To stop new sign-ins but keep the links, disable it instead.
    </p>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="pendingDelete = null" />
      <BaseButton
        label="Remove provider"
        variant="danger"
        :loading="providerAction.loading.value"
        @click="pendingDelete && providerAction.run(pendingDelete, 'delete')"
      />
    </template>
  </BaseDialog>
</template>
