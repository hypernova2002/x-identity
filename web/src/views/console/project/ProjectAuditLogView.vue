<script setup lang="ts">
import AuditLogPanel from '@/components/audit/AuditLogPanel.vue'
import { useProjectContext } from '@/composables/useProjectContext'
import type { ListParams } from '@/services/list'
import { projectAdminService } from '@/services/project'

const { accountUid, project } = useProjectContext()

function fetchPage(params: ListParams) {
  return projectAdminService.listAuditEvents(accountUid.value, project.value!.uid, params)
}
</script>

<template>
  <p class="text-sm text-text-muted">End-user activity and changes to this project, newest first. Try filtering by end_user. or app_client.</p>
  <AuditLogPanel v-if="project" :fetch-page="fetchPage" show-app-client />
</template>
