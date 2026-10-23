<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useSamlApp } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import { formatDateTime } from '@/utils/format'
import { nameIdFormatOptions } from '@/utils/samlApps'

const router = useRouter()
const { accountUid, project, access } = useProjectContext()
const { record: app, replace } = useSamlApp()

const assignmentCount = ref<number | null>(null)
const disableOpen = ref(false)
const deleteOpen = ref(false)

const params = computed(() => ({ projectUid: project.value?.uid, samlAppUid: app.value.uid }))
const nameIdLabel = computed(() => nameIdFormatOptions.find((option) => option.value === app.value.name_id_format)?.label)
const signing = computed(() => [app.value.sign_assertion && 'assertion', app.value.sign_response && 'whole response'].filter(Boolean).join(' and '))

const checks = computed(() => [
  {
    done: (assignmentCount.value ?? 0) > 0,
    label: 'People can sign in',
    detail: assignmentCount.value === null ? 'Checking…' : assignmentCount.value > 0 ? `Assigned to ${assignmentCount.value} group(s) or user(s).` : 'Nobody is assigned yet.',
    to: 'project-saml-app-access',
  },
  { done: app.value.slo_url !== null, label: 'Single logout', detail: app.value.slo_url ?? 'Optional: without a logout URL, logging out doesn\'t reach this app.', to: 'project-saml-app-configuration' },
  {
    done: app.value.require_signed_requests,
    label: 'Signed requests required',
    detail: app.value.require_signed_requests ? 'Unsigned sign-in requests are refused.' : 'Optional: needs the app\'s certificate.',
    to: 'project-saml-app-configuration',
  },
])

const loadAssignments = useAsyncAction(async () => {
  if (!project.value) return
  assignmentCount.value = (await projectAdminService.listAssignments(accountUid.value, project.value.uid, 'saml_app', app.value.uid)).total
})

const toggle = useAsyncAction(async () => {
  if (!project.value) return
  replace(await projectAdminService.updateSamlApp(accountUid.value, project.value.uid, app.value.uid, { enabled: !app.value.enabled }))
  disableOpen.value = false
})

const destroy = useAsyncAction(async () => {
  if (!project.value) return
  await projectAdminService.deleteSamlApp(accountUid.value, project.value.uid, app.value.uid)
  await router.push({ name: 'project-applications', params: { projectUid: project.value.uid } })
})

onMounted(() => loadAssignments.run())
</script>

<template>
  <BaseCard title="Summary">
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">Entity ID</dt>
      <dd class="font-mono text-xs break-all">{{ app.entity_id }}</dd>
      <dt class="font-medium">Sign-in URL (ACS)</dt>
      <dd class="font-mono text-xs break-all">{{ app.acs_urls[0] }}<span v-if="app.acs_urls.length > 1" class="text-text-muted"> and {{ app.acs_urls.length - 1 }} more</span></dd>
      <dt class="font-medium">NameID</dt>
      <dd>{{ nameIdLabel }}</dd>
      <dt class="font-medium">Signing</dt>
      <dd>{{ signing || 'Not signed' }}</dd>
      <dt class="font-medium">Created</dt>
      <dd>{{ formatDateTime(app.created_at) }}</dd>
    </dl>
  </BaseCard>

  <BaseCard title="Configuration status">
    <BaseAlert v-if="loadAssignments.error.value" variant="danger">{{ loadAssignments.error.value.message }}</BaseAlert>
    <ul class="flex flex-col divide-y divide-border">
      <li v-for="check in checks" :key="check.label" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
        <span class="flex flex-col">
          <span class="font-medium">{{ check.label }}</span>
          <span class="text-xs break-all text-text-muted">{{ check.detail }}</span>
        </span>
        <span class="flex items-center gap-2">
          <StatusBadge :tone="check.done ? 'success' : 'neutral'" :label="check.done ? 'Set' : 'Not set'" />
          <RouterLink :to="{ name: check.to, params }" class="text-sm font-medium text-primary underline">Review</RouterLink>
        </span>
      </li>
    </ul>
  </BaseCard>

  <BaseCard title="Try it" description="Opens the app with an IdP-initiated sign-in, as the app portal does. You sign in as an end user if you haven't already.">
    <a :href="app.launch_url" target="_blank" rel="noopener" class="self-start text-sm font-medium text-primary underline">Launch {{ app.name }}</a>
  </BaseCard>

  <BaseCard v-if="access.developer" title="Manage">
    <BaseAlert v-if="toggle.error.value" variant="danger">{{ toggle.error.value.message }}</BaseAlert>
    <div class="flex flex-wrap gap-2">
      <BaseButton v-if="app.enabled" label="Disable" variant="secondary" @click="disableOpen = true" />
      <BaseButton v-else label="Enable" variant="secondary" :loading="toggle.loading.value" @click="toggle.run()" />
      <BaseButton label="Delete application" variant="danger" @click="deleteOpen = true" />
    </div>
  </BaseCard>

  <ConfirmDialog v-model:visible="disableOpen" title="Disable this SAML application?" confirm-label="Disable" danger :loading="toggle.loading.value" :error="toggle.error.value" @confirm="toggle.run()">
    <p>Sign-in requests from <strong>{{ app.name }}</strong> are refused while it's disabled. Sessions it already has in the app aren't ended.</p>
  </ConfirmDialog>
  <ConfirmDialog v-model:visible="deleteOpen" title="Delete this SAML application?" confirm-label="Delete application" danger :loading="destroy.loading.value" :error="destroy.error.value" @confirm="destroy.run()">
    <p>Users can no longer sign in to <strong>{{ app.name }}</strong> with this project, and its access assignments are removed. This can't be undone.</p>
  </ConfirmDialog>
</template>
