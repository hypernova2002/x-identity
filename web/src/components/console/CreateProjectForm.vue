<script setup lang="ts">
import { ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { projectService } from '@/services/account'
import type { Project } from '@/types/api'

const props = defineProps<{
  accountUid: string
  submitLabel?: string
}>()

const emit = defineEmits<{
  created: [project: Project]
}>()

const name = ref('')

const { loading, error, run } = useAsyncAction(async () => {
  const project = await projectService.create(props.accountUid, name.value)
  name.value = ''
  emit('created', project)
})
</script>

<template>
  <form class="flex flex-col gap-4" novalidate @submit.prevent="run()">
    <BaseAlert v-if="error && error.details.length === 0" variant="danger">{{ error.message }}</BaseAlert>
    <BaseInput
      v-model="name"
      :label="$t('common.createProject.name')"
      required
      :hint="$t('common.createProject.nameHint')"
      :error="error?.fieldError('name')"
    />
    <BaseButton type="submit" :label="submitLabel ?? $t('common.createProject.submit')" :loading="loading" class="self-start" />
  </form>
</template>
