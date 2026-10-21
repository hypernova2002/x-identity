<script setup lang="ts">
import { storeToRefs } from 'pinia'

import PageHeader from '@/components/console/PageHeader.vue'
import AuthConfigurationForm from '@/components/settings/AuthConfigurationForm.vue'
import { accountService } from '@/services/account'
import { useSessionStore } from '@/stores/session'
import type { AuthConfiguration } from '@/types/api'

const { account } = storeToRefs(useSessionStore())

function load() {
  return accountService.getAuthConfiguration(account.value!.uid)
}

function save(changes: Partial<AuthConfiguration>) {
  return accountService.updateAuthConfiguration(account.value!.uid, changes)
}
</script>

<template>
  <PageHeader
    title="Authentication"
    description="How people sign in to this account's console. Changes apply from each user's next sign-in or token refresh."
  />
  <AuthConfigurationForm
    v-if="account"
    :load="load"
    :save="save"
    email-verification-hint="Off by default while the console is being tested."
  />
</template>
