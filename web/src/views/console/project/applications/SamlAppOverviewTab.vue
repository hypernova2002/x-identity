<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
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
import { formatList } from '@/i18n'

const { t } = useI18n()

const router = useRouter()
const { accountUid, project, access } = useProjectContext()
const { record: app, replace } = useSamlApp()

const assignmentCount = ref<number | null>(null)
const disableOpen = ref(false)
const deleteOpen = ref(false)

const params = computed(() => ({ projectUid: project.value?.uid, samlAppUid: app.value.uid }))
const nameIdLabel = computed(() => nameIdFormatOptions.find((option) => option.value === app.value.name_id_format)?.label)
const signing = computed(() =>
  formatList(
    [app.value.sign_assertion && t('project.samlAppOverview.signingParts.assertion'), app.value.sign_response && t('project.samlAppOverview.signingParts.response')].filter(
      (part): part is string => Boolean(part),
    ),
  ),
)

const checks = computed(() => [
  {
    done: (assignmentCount.value ?? 0) > 0,
    label: t('project.samlAppOverview.peopleCanSignIn'),
    detail: assignmentCount.value === null ? t('project.samlAppOverview.checking') : assignmentCount.value > 0 ? t('project.samlAppOverview.assignedToGroupSOr', { assignmentCountValue: assignmentCount.value }) : t('project.samlAppOverview.nobodyIsAssignedYet'),
    to: 'project-saml-app-access',
  },
  { done: app.value.slo_url !== null, label: t('project.samlAppOverview.singleLogout'), detail: app.value.slo_url ?? t('project.samlAppOverview.optionalWithoutALogoutUrl'), to: 'project-saml-app-configuration' },
  {
    done: app.value.require_signed_requests,
    label: t('project.samlAppOverview.signedRequestsRequired'),
    detail: app.value.require_signed_requests ? t('project.samlAppOverview.unsignedSignInRequestsAre') : t('project.samlAppOverview.optionalNeedsTheAppS'),
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
  <BaseCard :title="$t('project.samlAppOverview.summary')">
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">{{ $t('project.samlAppOverview.entityId') }}</dt>
      <dd class="font-mono text-xs break-all">{{ app.entity_id }}</dd>
      <dt class="font-medium">{{ $t('project.samlAppOverview.signInUrlAcs') }}</dt>
      <dd class="font-mono text-xs break-all">{{ app.acs_urls[0] }}<span v-if="app.acs_urls.length > 1" class="text-text-muted"> {{ $t('project.samlAppOverview.andMore', { count: app.acs_urls.length - 1 }) }}</span></dd>
      <dt class="font-medium">{{ $t('project.samlAppOverview.nameid') }}</dt>
      <dd>{{ nameIdLabel }}</dd>
      <dt class="font-medium">{{ $t('project.samlAppOverview.signing') }}</dt>
      <dd>{{ signing || $t('project.samlAppOverview.notSigned') }}</dd>
      <dt class="font-medium">{{ $t('project.samlAppOverview.created') }}</dt>
      <dd>{{ formatDateTime(app.created_at) }}</dd>
    </dl>
  </BaseCard>

  <BaseCard :title="$t('project.samlAppOverview.configurationStatus')">
    <BaseAlert v-if="loadAssignments.error.value" variant="danger">{{ loadAssignments.error.value.message }}</BaseAlert>
    <ul class="flex flex-col divide-y divide-border">
      <li v-for="check in checks" :key="check.label" class="flex flex-wrap items-center justify-between gap-2 py-2 text-sm">
        <span class="flex flex-col">
          <span class="font-medium">{{ check.label }}</span>
          <span class="text-xs break-all text-text-muted">{{ check.detail }}</span>
        </span>
        <span class="flex items-center gap-2">
          <StatusBadge :tone="check.done ? 'success' : 'neutral'" :label="check.done ? $t('project.samlAppOverview.set') : $t('project.samlAppOverview.notSet')" />
          <RouterLink :to="{ name: check.to, params }" class="text-sm font-medium text-primary underline">{{ $t('project.samlAppOverview.review') }}</RouterLink>
        </span>
      </li>
    </ul>
  </BaseCard>

  <BaseCard :title="$t('project.samlAppOverview.tryIt')" :description="$t('project.samlAppOverview.opensTheAppWithAn')">
    <a :href="app.launch_url" target="_blank" rel="noopener" class="self-start text-sm font-medium text-primary underline">{{ $t('project.samlAppOverview.launch', { name: app.name }) }}</a>
  </BaseCard>

  <BaseCard v-if="access.developer" :title="$t('project.samlAppOverview.manage')">
    <BaseAlert v-if="toggle.error.value" variant="danger">{{ toggle.error.value.message }}</BaseAlert>
    <div class="flex flex-wrap gap-2">
      <BaseButton v-if="app.enabled" :label="$t('project.samlAppOverview.disable')" variant="secondary" @click="disableOpen = true" />
      <BaseButton v-else :label="$t('project.samlAppOverview.enable')" variant="secondary" :loading="toggle.loading.value" @click="toggle.run()" />
      <BaseButton :label="$t('project.samlAppOverview.deleteApplication')" variant="danger" @click="deleteOpen = true" />
    </div>
  </BaseCard>

  <ConfirmDialog v-model:visible="disableOpen" :title="$t('project.samlAppOverview.disableThisSamlApplication')" :confirm-label="$t('project.samlAppOverview.disable')" danger :loading="toggle.loading.value" :error="toggle.error.value" @confirm="toggle.run()">
    <i18n-t keypath="project.samlAppOverview.disableDescription" tag="p">
      <template #name><strong>{{ app.name }}</strong></template>
    </i18n-t>
  </ConfirmDialog>
  <ConfirmDialog v-model:visible="deleteOpen" :title="$t('project.samlAppOverview.deleteThisSamlApplication')" :confirm-label="$t('project.samlAppOverview.deleteApplication')" danger :loading="destroy.loading.value" :error="destroy.error.value" @confirm="destroy.run()">
    <i18n-t keypath="project.samlAppOverview.deleteDescription" tag="p">
      <template #name><strong>{{ app.name }}</strong></template>
    </i18n-t>
  </ConfirmDialog>
</template>
