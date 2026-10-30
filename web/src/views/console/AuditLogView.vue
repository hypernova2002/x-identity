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
    :title="$t('console.auditLog.title')"
    :description="$t('console.auditLog.description')"
  />
  <AuditLogPanel v-if="account" :fetch-page="fetchPage" />
</template>
