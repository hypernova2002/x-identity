<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useAppClient } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import { formatDateTime } from '@/utils/format'

const router = useRouter()
const { accountUid, project, access } = useProjectContext()
const { record: client, replace } = useAppClient()

const assignmentCount = ref<number | null>(null)
const disableOpen = ref(false)
const deleteOpen = ref(false)

const params = computed(() => ({ projectUid: project.value?.uid, clientUid: client.value.uid }))

/** What this client is set up for, from its actual settings. */
const checks = computed(() => [
  {
    done: (assignmentCount.value ?? 0) > 0,
    label: 'People can sign in',
    detail: assignmentCount.value === null ? 'Checking…' : assignmentCount.value > 0 ? `Assigned to ${assignmentCount.value} group(s) or user(s).` : 'Nobody is assigned yet.',
    to: 'project-app-client-access',
  },
  {
    done: client.value.redirect_uris.length > 0,
    label: 'Redirect URIs',
    detail: client.value.redirect_uris.length > 0 ? `${client.value.redirect_uris.length} registered.` : 'Needed for hosted login and identity provider sign-in.',
    to: 'project-app-client-sign-in',
  },
  {
    done: client.value.allowed_origins.length > 0,
    label: 'Allowed origins',
    detail: client.value.allowed_origins.length > 0 ? client.value.allowed_origins.join(', ') : 'Needed when a browser app calls the API directly.',
    to: 'project-app-client-sign-in',
  },
  {
    done: client.value.launch_url !== null,
    label: 'Listed in the app portal',
    detail: client.value.launch_url ?? 'Optional: add a launch URL to list it in the portal.',
    to: 'project-app-client-sign-in',
  },
])

const loadAssignments = useAsyncAction(async () => {
  if (!project.value) return
  assignmentCount.value = (await projectAdminService.listAssignments(accountUid.value, project.value.uid, 'app_client', client.value.uid)).total
})

const toggle = useAsyncAction(async () => {
  if (!project.value) return
  replace(await projectAdminService.updateAppClient(accountUid.value, project.value.uid, client.value.uid, { enabled: !client.value.enabled }))
  disableOpen.value = false
})

const destroy = useAsyncAction(async () => {
  if (!project.value) return
  await projectAdminService.deleteAppClient(accountUid.value, project.value.uid, client.value.uid)
  await router.push({ name: 'project-applications', params: { projectUid: project.value.uid } })
})

onMounted(() => loadAssignments.run())
</script>

<template>
  <BaseCard title="Summary">
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">Client ID</dt>
      <dd class="font-mono text-xs break-all">{{ client.uid }}</dd>
      <dt class="font-medium">Client type</dt>
      <dd>{{ client.client_type === 'public' ? 'Public: browser or mobile app, no secret' : 'Confidential: server-side app with a secret' }}</dd>
      <dt class="font-medium">Created</dt>
      <dd>{{ formatDateTime(client.created_at) }}</dd>
      <dt class="font-medium">Last changed</dt>
      <dd>{{ formatDateTime(client.updated_at) }}</dd>
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

  <BaseCard title="Try it">
    <p class="text-sm">Sign an end user in through this client to check the setup, step through challenges and inspect the tokens.</p>
    <RouterLink
      :to="{ name: 'project-test-sign-in', params: { projectUid: project?.uid }, query: { client: client.uid } }"
      class="self-start text-sm font-medium text-primary underline"
    >
      Test sign-in with {{ client.name }}
    </RouterLink>
  </BaseCard>

  <BaseCard v-if="access.developer" title="Manage">
    <BaseAlert v-if="toggle.error.value" variant="danger">{{ toggle.error.value.message }}</BaseAlert>
    <div class="flex flex-wrap gap-2">
      <BaseButton v-if="client.enabled" label="Disable" variant="secondary" @click="disableOpen = true" />
      <BaseButton v-else label="Enable" variant="secondary" :loading="toggle.loading.value" @click="toggle.run()" />
      <BaseButton label="Delete application" variant="danger" @click="deleteOpen = true" />
    </div>
  </BaseCard>

  <ConfirmDialog v-model:visible="disableOpen" title="Disable this client?" confirm-label="Disable" danger :loading="toggle.loading.value" :error="toggle.error.value" @confirm="toggle.run()">
    <p>
      Nobody can sign in through <strong>{{ client.name }}</strong> while it's disabled, and everyone currently signed in through it is
      signed out. You can enable it again later.
    </p>
  </ConfirmDialog>
  <ConfirmDialog v-model:visible="deleteOpen" title="Delete this client?" confirm-label="Delete application" danger :loading="destroy.loading.value" :error="destroy.error.value" @confirm="destroy.run()">
    <p>
      Apps using <strong>{{ client.name }}</strong> stop being able to sign end users in, and everyone signed in through it is signed
      out. Its access assignments are removed. This can't be undone.
    </p>
  </ConfirmDialog>
</template>
