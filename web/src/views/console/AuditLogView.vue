<script setup lang="ts">
import { storeToRefs } from 'pinia'

import AuditLogPanel from '@/components/audit/AuditLogPanel.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { accountService, type AuditEventFilters } from '@/services/account'
import { useSessionStore } from '@/stores/session'

const { account } = storeToRefs(useSessionStore())

function fetchPage(page: number, filters: AuditEventFilters) {
  return accountService.listAuditEvents(account.value!.uid, page, filters)
}
</script>

<template>
  <PageHeader
    title="Audit log"
    description="Account-level activity, newest first. Each project has its own log for its end users and settings."
  />
  <AuditLogPanel v-if="account" :fetch-page="fetchPage" />
</template>
