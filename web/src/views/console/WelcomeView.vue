<script setup lang="ts">
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseCard from '@/components/base/BaseCard.vue'
import CreateProjectForm from '@/components/console/CreateProjectForm.vue'
import PageHeader from '@/components/console/PageHeader.vue'
import { useSessionStore } from '@/stores/session'
import type { Project } from '@/types/api'

const router = useRouter()
const { account, me } = storeToRefs(useSessionStore())

function openProject(project: Project) {
  router.push({ name: 'project', params: { projectUid: project.uid } })
}
</script>

<template>
  <PageHeader :title="`Welcome, ${me?.name ?? ''}`" description="Your account is ready. Create your first project to get started." />
  <BaseCard
    v-if="account"
    title="Create your first project"
    description="Each project has its own users and settings. Most teams create one per environment."
  >
    <CreateProjectForm :account-uid="account.uid" @created="openProject" />
  </BaseCard>
</template>
