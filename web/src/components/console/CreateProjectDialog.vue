<script setup lang="ts">
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'

import BaseDialog from '@/components/base/BaseDialog.vue'
import CreateProjectForm from '@/components/console/CreateProjectForm.vue'
import { useProjectStore } from '@/stores/project'
import { useSessionStore } from '@/stores/session'
import type { Project } from '@/types/api'

const visible = defineModel<boolean>('visible', { required: true })

const router = useRouter()
const projectStore = useProjectStore()
const { account } = storeToRefs(useSessionStore())

function openProject(project: Project) {
  visible.value = false
  projectStore.upsert(project)
  router.push({ name: 'project', params: { projectUid: project.uid } })
}
</script>

<template>
  <BaseDialog v-if="account" v-model:visible="visible" :title="$t('common.createProject.title')">
    <p class="text-sm text-text-muted">{{ $t('common.createProject.description') }}</p>
    <CreateProjectForm :account-uid="account.uid" @created="openProject" />
  </BaseDialog>
</template>
