<script setup lang="ts">
import { storeToRefs } from 'pinia'

import AuditLogPanel from '@/components/audit/AuditLogPanel.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { accountService } from '@/services/account'
import type { ListParams } from '@/services/list'
import { useSessionStore } from '@/stores/session'

const { account } = storeToRefs(useSessionStore())

function fetchPage(params: ListParams) {
  return accountService.listAuditEvents(account.value!.uid, params)
}
</script>

<template>
  <PageHeader
    title="Audit log"
    description="Account-level activity, newest first. Each project has its own log for its end users and settings."
  />
  <AuditLogPanel v-if="account" :fetch-page="fetchPage" />
</template>
