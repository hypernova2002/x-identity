<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
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

const { t } = useI18n()

const router = useRouter()
const { accountUid, project, access } = useProjectContext()
const { record: client, replace } = useAppClient()

const assignmentCount = ref<number | null>(null)
const grantCount = ref<number | null>(null)
const disableOpen = ref(false)
const deleteOpen = ref(false)

const params = computed(() => ({ projectUid: project.value?.uid, clientUid: client.value.uid }))

/** What this client is set up for, from its actual settings. */
const checks = computed(() => (client.value.machine ? machineChecks.value : signInChecks.value))

const machineChecks = computed(() => [
  {
    done: (grantCount.value ?? 0) > 0,
    label: t('project.appClientOverview.canGetTokensForAn'),
    detail: grantCount.value === null ? t('project.appClientOverview.checking') : grantCount.value > 0 ? t('project.appClientOverview.hasAccessToApiS', { grantCountValue: grantCount.value }) : t('project.appClientOverview.noApiAccessYet'),
    to: 'project-app-client-api-access',
  },
])

const signInChecks = computed(() => [
  {
    done: (assignmentCount.value ?? 0) > 0,
    label: t('project.appClientOverview.peopleCanSignIn'),
    detail: assignmentCount.value === null ? t('project.appClientOverview.checking') : assignmentCount.value > 0 ? t('project.appClientOverview.assignedToGroupSOr', { assignmentCountValue: assignmentCount.value }) : t('project.appClientOverview.nobodyIsAssignedYet'),
    to: 'project-app-client-access',
  },
  {
    done: client.value.redirect_uris.length > 0,
    label: t('project.appClientOverview.redirectUris'),
    detail: client.value.redirect_uris.length > 0 ? t('project.appClientOverview.registered', { redirectUrisLength: client.value.redirect_uris.length }) : t('project.appClientOverview.neededForHostedLoginAnd'),
    to: 'project-app-client-sign-in',
  },
  {
    done: client.value.allowed_origins.length > 0,
    label: t('project.appClientOverview.allowedOrigins'),
    detail: client.value.allowed_origins.length > 0 ? client.value.allowed_origins.join(', ') : t('project.appClientOverview.neededWhenABrowserApp'),
    to: 'project-app-client-sign-in',
  },
  {
    done: client.value.launch_url !== null,
    label: t('project.appClientOverview.listedInTheAppPortal'),
    detail: client.value.launch_url ?? t('project.appClientOverview.optionalAddALaunchUrl'),
    to: 'project-app-client-sign-in',
  },
])

const loadAssignments = useAsyncAction(async () => {
  if (!project.value) return
  if (client.value.machine) grantCount.value = (await projectAdminService.listApiGrants(accountUid.value, project.value.uid, client.value.uid)).length
  else assignmentCount.value = (await projectAdminService.listAssignments(accountUid.value, project.value.uid, 'app_client', client.value.uid)).total
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
  <BaseCard :title="$t('project.appClientOverview.summary')">
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">{{ $t('project.appClientOverview.clientId') }}</dt>
      <dd class="font-mono text-xs break-all">{{ client.uid }}</dd>
      <dt class="font-medium">{{ $t('project.appClientOverview.clientType') }}</dt>
      <dd v-if="client.machine">{{ $t('project.appClientOverview.machineToMachineAService') }}</dd>
      <dd v-else>{{ client.client_type === 'public' ? $t('project.appClientOverview.publicBrowserOrMobileApp') : $t('project.appClientOverview.confidentialServerSideAppWith') }}</dd>
      <dt class="font-medium">{{ $t('project.appClientOverview.created') }}</dt>
      <dd>{{ formatDateTime(client.created_at) }}</dd>
      <dt class="font-medium">{{ $t('project.appClientOverview.lastChanged') }}</dt>
      <dd>{{ formatDateTime(client.updated_at) }}</dd>
    </dl>
  </BaseCard>

  <BaseCard :title="$t('project.appClientOverview.configurationStatus')">
    <BaseAlert v-if="loadAssignments.error.value" variant="danger">{{ loadAssignments.error.value.message }}</BaseAlert>
    <ul class="flex flex-col divide-y divide-border">
      <li v-for="check in checks" :key="check.label" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
        <span class="flex flex-col">
          <span class="font-medium">{{ check.label }}</span>
          <span class="text-xs break-all text-text-muted">{{ check.detail }}</span>
        </span>
        <span class="flex items-center gap-2">
          <StatusBadge :tone="check.done ? 'success' : 'neutral'" :label="check.done ? $t('project.appClientOverview.set') : $t('project.appClientOverview.notSet')" />
          <RouterLink :to="{ name: check.to, params }" class="text-sm font-medium text-primary underline">{{ $t('project.appClientOverview.review') }}</RouterLink>
        </span>
      </li>
    </ul>
  </BaseCard>

  <BaseCard v-if="!client.machine" :title="$t('project.appClientOverview.tryIt')">
    <p class="text-sm">{{ $t('project.appClientOverview.signAnEndUserIn') }}</p>
    <RouterLink
      :to="{ name: 'project-test-sign-in', params: { projectUid: project?.uid }, query: { client: client.uid } }"
      class="self-start text-sm font-medium text-primary underline"
    >
      {{ $t('project.appClientOverview.testSignInWith', { name: client.name }) }}
    </RouterLink>
  </BaseCard>

  <BaseCard v-if="access.developer" :title="$t('project.appClientOverview.manage')">
    <BaseAlert v-if="toggle.error.value" variant="danger">{{ toggle.error.value.message }}</BaseAlert>
    <div class="flex flex-wrap gap-2">
      <BaseButton v-if="client.enabled" :label="$t('project.appClientOverview.disable')" variant="secondary" @click="disableOpen = true" />
      <BaseButton v-else :label="$t('project.appClientOverview.enable')" variant="secondary" :loading="toggle.loading.value" @click="toggle.run()" />
      <BaseButton :label="$t('project.appClientOverview.deleteApplication')" variant="danger" @click="deleteOpen = true" />
    </div>
  </BaseCard>

  <ConfirmDialog v-model:visible="disableOpen" :title="$t('project.appClientOverview.disableThisClient')" :confirm-label="$t('project.appClientOverview.disable')" danger :loading="toggle.loading.value" :error="toggle.error.value" @confirm="toggle.run()">
    <i18n-t keypath="project.appClientOverview.disableMachineDescription" tag="p" v-if="client.machine">
      <template #name><strong>{{ client.name }}</strong></template>
    </i18n-t>
    <i18n-t keypath="project.appClientOverview.disableDescription" tag="p" v-else>
      <template #name><strong>{{ client.name }}</strong></template>
    </i18n-t>
  </ConfirmDialog>
  <ConfirmDialog v-model:visible="deleteOpen" :title="$t('project.appClientOverview.deleteThisClient')" :confirm-label="$t('project.appClientOverview.deleteApplication')" danger :loading="destroy.loading.value" :error="destroy.error.value" @confirm="destroy.run()">
    <i18n-t keypath="project.appClientOverview.deleteMachineDescription" tag="p" v-if="client.machine">
      <template #name><strong>{{ client.name }}</strong></template>
    </i18n-t>
    <i18n-t keypath="project.appClientOverview.deleteDescription" tag="p" v-else>
      <template #name><strong>{{ client.name }}</strong></template>
    </i18n-t>
  </ConfirmDialog>
</template>
