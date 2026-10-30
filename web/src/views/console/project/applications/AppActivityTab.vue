<script setup lang="ts">
import { computed } from 'vue'

import AuditEventList from '@/components/audit/AuditEventList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import { useApplication } from '@/composables/useApplicationContext'
import { useProjectContext } from '@/composables/useProjectContext'
import type { ListParams } from '@/services/list'
import { projectAdminService } from '@/services/project'

const { accountUid, project, access } = useProjectContext()
const application = useApplication()

function fetchPage(params: ListParams) {
  return projectAdminService.listAuditEvents(accountUid.value, project.value!.uid, params)
}

const appFilter = computed((): Record<string, string> => ({
  [application.value.kind === 'saml_app' ? 'saml_app_uid_eq' : 'app_client_uid_eq']: application.value.uid,
}))

const auditLog = (query: Record<string, string>) => ({ name: 'project-audit-log', params: { projectUid: project.value?.uid }, query })
</script>

<template>
  <BaseAlert v-if="!access.developer" variant="info">{{ $t('project.appActivity.onlyProjectAdminsAndDevelopers') }}</BaseAlert>

  <template v-else-if="project">
    <BaseCard :title="$t('project.appActivity.signInsAndRefusalsThrough')">
      <AuditEventList
        :fetch-page="fetchPage"
        :filters="appFilter"
        :empty-message="$t('project.appActivity.noSignInsThroughThis')"
        :full-log="auditLog(appFilter)"
      />
    </BaseCard>

    <BaseCard :title="$t('project.appActivity.configurationAndAccessChanges')">
      <AuditEventList
        :fetch-page="fetchPage"
        :filters="{ target_uid_eq: application.uid }"
        :empty-message="$t('project.appActivity.noChangesRecordedYet')"
        :full-log="auditLog({ target_uid_eq: application.uid })"
      />
    </BaseCard>

  </template>
</template>
