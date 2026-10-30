<script setup lang="ts">
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseCard from '@/components/base/BaseCard.vue'
import CreateProjectForm from '@/components/console/CreateProjectForm.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'
import type { Project } from '@/types/api'

const router = useRouter()
const { account, me } = storeToRefs(useSessionStore())

const projectStore = useProjectStore()

function openProject(project: Project) {
  projectStore.upsert(project)
  router.push({ name: 'project', params: { projectUid: project.uid } })
}
</script>

<template>
  <PageHeader :title="$t('console.welcome.title', { name: me?.name ?? '' })" :description="$t('console.welcome.description')" />
  <BaseCard
    v-if="account"
    :title="$t('console.welcome.createTitle')"
    :description="$t('console.welcome.createDescription')"
  >
    <CreateProjectForm :account-uid="account.uid" @created="openProject" />
  </BaseCard>
</template>
