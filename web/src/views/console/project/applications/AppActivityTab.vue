<script setup lang="ts">
import AuditEventList from '@/components/audit/AuditEventList.vue'
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import { useApplication } from '@/composables/useApplicationContext'
import { useProjectContext } from '@/composables/useProjectContext'
import type { AuditEventFilters } from '@/services/account'
import { projectAdminService } from '@/services/project'

const { accountUid, project, access } = useProjectContext()
const application = useApplication()

function fetchPage(page: number, filters: AuditEventFilters) {
  return projectAdminService.listAuditEvents(accountUid.value, project.value!.uid, page, filters)
}

const auditLog = (query: Record<string, string>) => ({ name: 'project-audit-log', params: { projectUid: project.value?.uid }, query })
</script>

<template>
  <BaseAlert v-if="!access.developer" variant="info">Only project admins and developers can read the audit log.</BaseAlert>

  <template v-else-if="project">
    <BaseCard v-if="application.kind === 'app_client'" title="Sign-ins and refusals through this app">
      <AuditEventList
        :fetch-page="fetchPage"
        :filters="{ app_client_uid_eq: application.uid }"
        empty-message="No sign-ins through this app yet."
        :full-log="auditLog({ app_client_uid_eq: application.uid })"
      />
    </BaseCard>

    <BaseCard title="Configuration and access changes">
      <AuditEventList
        :fetch-page="fetchPage"
        :filters="{ target_uid_eq: application.uid }"
        empty-message="No changes recorded yet."
        :full-log="auditLog({ target_uid_eq: application.uid })"
      />
    </BaseCard>

    <p v-if="application.kind === 'saml_app'" class="text-sm text-text-muted">
      SAML sign-ins are recorded on each end user (<code class="font-mono text-xs">end_user.signed_in_to_app</code>), so they're in the
      audit log under the user rather than here.
    </p>
  </template>
</template>
