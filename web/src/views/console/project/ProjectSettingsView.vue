<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { useUnsavedChanges } from '@/composables/useUnsavedChanges'
import { projectService } from '@/services/account'
import { useProjectStore } from '@/stores/project'
import type { Project } from '@/types/api'

const router = useRouter()
const projectStore = useProjectStore()
const { accountUid, project, access } = useProjectContext()

const name = ref('')
const allowSelfSignUp = ref(true)
const confirmSignUpUrl = ref('')
const resetPasswordUrl = ref('')
const acceptInvitationUrl = ref('')
const saved = ref(false)
const deleteOpen = ref(false)

const form = computed(() => ({
  name: name.value,
  allow_self_sign_up: allowSelfSignUp.value,
  confirm_sign_up_url: confirmSignUpUrl.value.trim() || null,
  reset_password_url: resetPasswordUrl.value.trim() || null,
  accept_invitation_url: acceptInvitationUrl.value.trim() || null,
}))

function savedValues(value: Project) {
  return {
    name: value.name,
    allow_self_sign_up: value.allow_self_sign_up,
    confirm_sign_up_url: value.confirm_sign_up_url,
    reset_password_url: value.reset_password_url,
    accept_invitation_url: value.accept_invitation_url,
  }
}

const dirty = computed(() => project.value !== null && JSON.stringify(form.value) !== JSON.stringify(savedValues(project.value)))
useUnsavedChanges(dirty)

function reset(value: Project) {
  name.value = value.name
  allowSelfSignUp.value = value.allow_self_sign_up
  confirmSignUpUrl.value = value.confirm_sign_up_url ?? ''
  resetPasswordUrl.value = value.reset_password_url ?? ''
  acceptInvitationUrl.value = value.accept_invitation_url ?? ''
}

watch(project, (value) => value && reset(value), { immediate: true })

const save = useAsyncAction(async () => {
  if (!project.value) return
  saved.value = false
  projectStore.upsert(await projectService.update(accountUid.value, project.value.uid, form.value))
  saved.value = true
})

const destroy = useAsyncAction(async () => {
  if (!project.value) return
  const projectUid = project.value.uid
  await projectService.remove(accountUid.value, projectUid)
  projectStore.remove(projectUid)
  await router.push({ name: 'console-home' })
})
</script>

<template>
  <template v-if="project">
    <BaseCard :title="$t('project.projectSettings.project')">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">{{ $t('project.projectSettings.projectId') }}</dt>
        <dd class="font-mono text-xs break-all">{{ project.uid }}</dd>
        <dt class="font-medium">{{ $t('project.projectSettings.issuerAndApiBaseUrl') }}</dt>
        <dd class="font-mono text-xs break-all">{{ project.token_issuer }}</dd>
      </dl>
    </BaseCard>

    <form class="flex flex-col gap-6" novalidate @submit.prevent="save.run()">
      <BaseAlert v-if="saved && !dirty" variant="success">{{ $t('project.projectSettings.settingsSaved') }}</BaseAlert>
      <BaseAlert v-if="!access.admin" variant="info">{{ $t('project.projectSettings.onlyProjectAndAccountAdmins') }}</BaseAlert>
      <BaseAlert v-if="save.error.value && save.error.value.details.length === 0" variant="danger">{{ save.error.value.message }}</BaseAlert>

      <fieldset :disabled="!access.admin" class="contents">
        <BaseCard :title="$t('project.projectSettings.general')">
          <BaseInput v-model="name" :label="$t('project.projectSettings.projectName')" required :error="save.error.value?.fieldError('name')" />
          <BaseCheckbox
            v-model="allowSelfSignUp"
            :label="$t('project.projectSettings.allowSelfSignUp')"
            :hint="$t('project.projectSettings.whenOffOnlyAdminsCan')"
          />
        </BaseCard>

        <BaseCard :title="$t('project.projectSettings.emailLinks')" :description="$t('project.projectSettings.pagesInYourAppThat')">
          <i18n-t keypath="project.projectSettings.emailLinksHelp" tag="p" class="text-sm text-text-muted">
            <template #placeholder><code class="font-mono">{{ '{token}' }}</code></template>
            <template #example><code class="font-mono">{{ 'https://shop.example.com/confirm?token={token}' }}</code></template>
          </i18n-t>
          <BaseInput
            v-model="confirmSignUpUrl"
            :label="$t('project.projectSettings.confirmSignUpPage')"
            type="url"
            :error="save.error.value?.fieldError('confirm_sign_up_url')"
          />
          <BaseInput
            v-model="resetPasswordUrl"
            :label="$t('project.projectSettings.resetPasswordPage')"
            type="url"
            :error="save.error.value?.fieldError('reset_password_url')"
          />
          <BaseInput
            v-model="acceptInvitationUrl"
            :label="$t('project.projectSettings.acceptInvitationPage')"
            type="url"
            :error="save.error.value?.fieldError('accept_invitation_url')"
          />
        </BaseCard>
      </fieldset>

      <div v-if="access.admin" class="flex flex-wrap items-center gap-2">
        <BaseButton type="submit" :label="$t('project.projectSettings.saveChanges')" :loading="save.loading.value" :disabled="!dirty" />
        <BaseButton v-if="dirty" :label="$t('project.projectSettings.discardChanges')" variant="secondary" @click="reset(project)" />
        <span v-if="dirty" class="text-sm text-text-muted" role="status">{{ $t('project.projectSettings.unsavedChanges') }}</span>
      </div>
    </form>

    <BaseCard v-if="access.accountAdmin" :title="$t('project.projectSettings.deleteProject')" :description="$t('project.projectSettings.deletesTheProjectWithAll')">
      <BaseButton :label="$t('project.projectSettings.deleteProject')" variant="danger" class="self-start" @click="deleteOpen = true" />
    </BaseCard>

    <ConfirmDialog
      v-model:visible="deleteOpen"
      :title="$t('project.projectSettings.deleteProject2')"
      :confirm-label="$t('project.projectSettings.deleteProject')"
      danger
      :loading="destroy.loading.value"
      :error="destroy.error.value"
      @confirm="destroy.run()"
    >
      <i18n-t keypath="project.projectSettings.deleteDescription" tag="p">
        <template #name><strong>{{ project.name }}</strong></template>
      </i18n-t>
    </ConfirmDialog>
  </template>
</template>
