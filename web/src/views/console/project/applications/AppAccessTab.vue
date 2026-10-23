<script setup lang="ts">
import AppAccessPanel from '@/components/project/AppAccessPanel.vue'
import { useApplication } from '@/composables/useApplicationContext'
import { useProjectContext } from '@/composables/useProjectContext'

const { accountUid, project, access } = useProjectContext()
const application = useApplication()
</script>

<template>
  <AppAccessPanel v-if="project" :account-uid="accountUid" :project-uid="project.uid" :app="application" :can-manage="access.developer" />
</template>
