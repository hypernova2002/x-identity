<script setup lang="ts">
import AuditLogPanel from '@/components/audit/AuditLogPanel.vue'
import { useProjectContext } from '@/composables/useProjectContext'
import type { AuditEventFilters } from '@/services/account'
import { projectAdminService } from '@/services/project'

const { accountUid, project } = useProjectContext()

function fetchPage(page: number, filters: AuditEventFilters) {
  return projectAdminService.listAuditEvents(accountUid.value, project.value!.uid, page, filters)
}
</script>

<template>
  <p class="text-sm text-text-muted">End-user activity and changes to this project, newest first. Try filtering by end_user. or app_client.</p>
  <AuditLogPanel v-if="project" :fetch-page="fetchPage" show-app-client />
</template>
