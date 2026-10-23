<script setup lang="ts">
import { computed } from 'vue'
import { RouterView } from 'vue-router'

import PageHeader from '@/components/console/PageHeader.vue'
import RouteTabs, { type RouteTab } from '@/components/console/RouteTabs.vue'
import { useProjectContext } from '@/composables/useProjectContext'
import { authSettingsSections } from '@/utils/authSettings'

const { project } = useProjectContext()

const tabNames = { 'sign-in': 'project-auth-sign-in', mfa: 'project-auth-mfa', policies: 'project-auth-policies', tokens: 'project-auth-tokens', signing: 'project-auth-keys' }

const tabs = computed<RouteTab[]>(() =>
  authSettingsSections.map(({ section, label }) => ({
    label,
    name: tabNames[section],
    to: { name: tabNames[section], params: { projectUid: project.value?.uid } },
  })),
)
</script>

<template>
  <PageHeader
    title="Authentication settings"
    :description="`How end users of ${project?.name ?? 'this project'} sign in. These policies apply to the whole project; changes apply from each user's next sign-in or token refresh.`"
  />
  <RouteTabs label="Authentication settings" :tabs="tabs" />
  <RouterView />
</template>
