<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import AppAccessDialog from '@/components/project/AppAccessDialog.vue'
import SamlAppForm from '@/components/project/SamlAppForm.vue'
import type { AppRef } from '@/composables/useAppAccess'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { SamlApp, SamlCertificate, SamlIdentityProviderInfo } from '@/types/api'
import { formatDateTime } from '@/utils/format'
import { emptySamlAppDraft, samlAppDraftFrom, samlAppInputFrom, withMetadata, type SamlAppDraft } from '@/utils/samlApps'

const { accountUid, project, access } = useProjectContext()

const apps = ref<SamlApp[]>([])
const idp = ref<SamlIdentityProviderInfo | null>(null)
const editing = ref<SamlApp | null>(null)
const formOpen = ref(false)
const draft = ref<SamlAppDraft>(emptySamlAppDraft())
const accessFor = ref<AppRef | null>(null)
const pendingDelete = ref<SamlApp | null>(null)
const notice = ref<string | null>(null)

const activeCertificate = computed(() => idp.value?.certificates.find((certificate) => certificate.status === 'active'))
const statusLabel: Record<SamlCertificate['status'], string> = { active: 'Signing now', next: 'Published, not yet used', retired: 'Retired, still published' }

const columns = [
  { key: 'name', label: 'App' },
  { key: 'acs_urls', label: 'Sign-in URL' },
  { key: 'enabled', label: 'Status' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const load = useAsyncAction(async () => {
  if (!project.value) return
  const [loadedApps, loadedIdp] = await Promise.all([
    projectAdminService.listSamlApps(accountUid.value, project.value.uid),
    projectAdminService.getSamlIdentityProvider(accountUid.value, project.value.uid),
  ])
  apps.value = loadedApps.items
  idp.value = loadedIdp
})

function openForm(app: SamlApp | null) {
  editing.value = app
  draft.value = app ? samlAppDraftFrom(app) : emptySamlAppDraft()
  save.error.value = null
  importMetadata.error.value = null
  formOpen.value = true
}

const importMetadata = useAsyncAction(async (source: { metadata_xml: string } | { metadata_url: string }) => {
  if (!project.value) return
  draft.value = withMetadata(draft.value, await projectAdminService.parseSamlMetadata(accountUid.value, project.value.uid, source))
})

const save = useAsyncAction(async () => {
  if (!project.value) return
  const input = samlAppInputFrom(draft.value)
  const saved = editing.value
    ? await projectAdminService.updateSamlApp(accountUid.value, project.value.uid, editing.value.uid, input)
    : await projectAdminService.createSamlApp(accountUid.value, project.value.uid, input)
  apps.value = editing.value ? apps.value.map((app) => (app.uid === saved.uid ? saved : app)) : [...apps.value, saved]
  notice.value = editing.value ? `${saved.name} was saved.` : `${saved.name} was added. Assign it to groups or end users so they can use it.`
  formOpen.value = false
})

const appAction = useAsyncAction(async (app: SamlApp, action: 'toggle' | 'delete') => {
  if (!project.value) return
  notice.value = null
  if (action === 'delete') {
    await projectAdminService.deleteSamlApp(accountUid.value, project.value.uid, app.uid)
    apps.value = apps.value.filter((existing) => existing.uid !== app.uid)
    pendingDelete.value = null
    return
  }
  const updated = await projectAdminService.updateSamlApp(accountUid.value, project.value.uid, app.uid, { enabled: !app.enabled })
  apps.value = apps.value.map((existing) => (existing.uid === updated.uid ? updated : existing))
})

const certificateAction = useAsyncAction(async (action: 'add' | 'activate' | 'remove', certificate?: SamlCertificate) => {
  if (!project.value) return
  const ids = [accountUid.value, project.value.uid] as const
  if (action === 'add') await projectAdminService.addSamlCertificate(...ids)
  if (action === 'activate' && certificate) await projectAdminService.activateSamlCertificate(...ids, certificate.uid)
  if (action === 'remove' && certificate) await projectAdminService.removeSamlCertificate(...ids, certificate.uid)
  idp.value = await projectAdminService.getSamlIdentityProvider(...ids)
})

function downloadCertificate(certificate: SamlCertificate) {
  const link = document.createElement('a')
  link.href = URL.createObjectURL(new Blob([certificate.certificate], { type: 'application/x-pem-file' }))
  link.download = `${project.value?.name ?? 'project'}-saml.pem`
  link.click()
  URL.revokeObjectURL(link.href)
}

onMounted(() => load.run())
</script>

<template>
  <BaseCard v-if="idp" title="Identity provider details" description="What to enter in each app's SAML settings, or import the metadata URL.">
    <dl class="grid gap-3 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">Metadata URL and entity ID</dt>
      <dd class="font-mono text-xs break-all">{{ idp.metadata_url }}</dd>
      <dt class="font-medium">Sign-on URL</dt>
      <dd class="font-mono text-xs break-all">{{ idp.sso_url }}</dd>
      <dt class="font-medium">Logout URL</dt>
      <dd class="font-mono text-xs break-all">{{ idp.slo_url }}</dd>
      <template v-if="activeCertificate">
        <dt class="font-medium">Certificate fingerprint (SHA-256)</dt>
        <dd class="font-mono text-xs break-all">{{ activeCertificate.fingerprint_sha256 }}</dd>
      </template>
    </dl>

    <section class="flex flex-col gap-2" aria-labelledby="saml-certificates-heading">
      <h3 id="saml-certificates-heading" class="text-sm font-semibold">Signing certificates</h3>
      <BaseAlert v-if="certificateAction.error.value" variant="danger">{{ certificateAction.error.value.message }}</BaseAlert>
      <ul class="flex flex-col divide-y divide-border">
        <li v-for="certificate in idp.certificates" :key="certificate.uid" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
          <span>
            <span class="font-medium">{{ statusLabel[certificate.status] }}</span>
            <span class="block text-xs text-text-muted">Expires {{ formatDateTime(certificate.expires_at) }}</span>
          </span>
          <div class="flex flex-wrap gap-2">
            <BaseButton label="Download" variant="secondary" size="sm" @click="downloadCertificate(certificate)" />
            <template v-if="access.admin">
              <BaseButton
                v-if="certificate.status === 'next'"
                label="Start signing with it"
                variant="secondary"
                size="sm"
                :loading="certificateAction.loading.value"
                @click="certificateAction.run('activate', certificate)"
              />
              <BaseButton
                v-if="certificate.status !== 'active'"
                label="Remove"
                variant="ghost"
                size="sm"
                :loading="certificateAction.loading.value"
                @click="certificateAction.run('remove', certificate)"
              />
            </template>
          </div>
        </li>
      </ul>
      <p class="text-xs text-text-muted">
        To rotate: add a new certificate, give apps time to pick it up from the metadata (or upload it to them), then start signing with
        it. Remove the old one once no app needs it.
      </p>
      <BaseButton
        v-if="access.admin && !idp.certificates.some((certificate) => certificate.status === 'next')"
        label="Add new certificate"
        variant="secondary"
        size="sm"
        class="self-start"
        :loading="certificateAction.loading.value"
        @click="certificateAction.run('add')"
      />
    </section>
  </BaseCard>

  <BaseCard title="SAML apps" description="Apps that sign users in with SAML 2.0, using this project as the identity provider.">
    <template v-if="access.developer" #footer>
      <BaseButton label="Add SAML app" @click="openForm(null)" />
    </template>

    <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>
    <BaseAlert v-if="load.error.value" variant="danger">We couldn't load SAML apps. {{ load.error.value.message }}</BaseAlert>
    <BaseAlert v-if="appAction.error.value" variant="danger">{{ appAction.error.value.message }}</BaseAlert>

    <BaseTable
      caption="SAML apps"
      :columns="columns"
      :rows="apps"
      :row-key="(app) => app.uid"
      :loading="load.loading.value"
      empty-message="No SAML apps yet. Add one with its metadata, or its entity ID and sign-in URL."
    >
      <template #cell-name="{ row }">
        <span class="font-medium">{{ row.name }}</span>
        <code class="block font-mono text-xs break-all text-text-muted">{{ row.entity_id }}</code>
      </template>
      <template #cell-acs_urls="{ row }"><code class="font-mono text-xs break-all">{{ row.acs_urls[0] }}</code></template>
      <template #cell-enabled="{ row }">
        <span :class="row.enabled ? 'text-success' : 'text-text-muted'" class="font-medium">{{ row.enabled ? '● Enabled' : '○ Disabled' }}</span>
        <span class="block text-xs text-text-muted">{{ row.slo_url ? 'Single logout' : 'No single logout' }}</span>
      </template>
      <template #cell-actions="{ row }">
        <div class="flex flex-wrap justify-end gap-2">
          <BaseButton label="Access" variant="secondary" size="sm" @click="accessFor = { kind: 'saml_app', uid: row.uid, name: row.name }" />
          <template v-if="access.developer">
            <BaseButton label="Edit" variant="secondary" size="sm" @click="openForm(row)" />
            <BaseButton :label="row.enabled ? 'Disable' : 'Enable'" variant="secondary" size="sm" :disabled="appAction.loading.value" @click="appAction.run(row, 'toggle')" />
            <BaseButton label="Delete" variant="ghost" size="sm" @click="pendingDelete = row" />
          </template>
        </div>
      </template>
    </BaseTable>
  </BaseCard>

  <BaseDialog v-model:visible="formOpen" :title="editing ? `Edit ${editing.name}` : 'Add SAML app'">
    <SamlAppForm
      v-model="draft"
      form-id="saml-app-form"
      :error="save.error.value"
      :import-error="importMetadata.error.value"
      :importing="importMetadata.loading.value"
      @submit="save.run()"
      @import-metadata="(source) => importMetadata.run(source)"
    />
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="formOpen = false" />
      <BaseButton :label="editing ? 'Save' : 'Add app'" type="submit" form="saml-app-form" :loading="save.loading.value" />
    </template>
  </BaseDialog>

  <AppAccessDialog v-if="project" :account-uid="accountUid" :project-uid="project.uid" :app="accessFor" :can-manage="access.developer" @close="accessFor = null" />

  <BaseDialog :visible="pendingDelete !== null" title="Delete SAML app?" @update:visible="(open: boolean) => !open && (pendingDelete = null)">
    <p class="text-sm">Users will no longer be able to sign in to <strong>{{ pendingDelete?.name }}</strong> with this project.</p>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="pendingDelete = null" />
      <BaseButton label="Delete app" variant="danger" :loading="appAction.loading.value" @click="pendingDelete && appAction.run(pendingDelete, 'delete')" />
    </template>
  </BaseDialog>
</template>
