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
    <BaseCard title="Project">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">Project ID</dt>
        <dd class="font-mono text-xs break-all">{{ project.uid }}</dd>
        <dt class="font-medium">Issuer and API base URL</dt>
        <dd class="font-mono text-xs break-all">{{ project.token_issuer }}</dd>
      </dl>
    </BaseCard>

    <form class="flex flex-col gap-6" novalidate @submit.prevent="save.run()">
      <BaseAlert v-if="saved && !dirty" variant="success">Settings saved.</BaseAlert>
      <BaseAlert v-if="!access.admin" variant="info">Only project and account admins can change these settings.</BaseAlert>
      <BaseAlert v-if="save.error.value && save.error.value.details.length === 0" variant="danger">{{ save.error.value.message }}</BaseAlert>

      <fieldset :disabled="!access.admin" class="contents">
        <BaseCard title="General">
          <BaseInput v-model="name" label="Project name" required :error="save.error.value?.fieldError('name')" />
          <BaseCheckbox
            v-model="allowSelfSignUp"
            label="Allow self sign-up"
            hint="When off, only admins can create end users, and identity providers only create users if set to."
          />
        </BaseCard>

        <BaseCard title="Email links" description="Pages in your app that emails link to.">
          <p class="text-sm text-text-muted">
            Emails always include a 6-digit code. Add a page in your app to also include a link; use
            <code class="font-mono">{token}</code> where the link's token goes, e.g.
            <code class="font-mono">https://shop.example.com/confirm?token={token}</code>.
          </p>
          <BaseInput
            v-model="confirmSignUpUrl"
            label="Confirm sign-up page"
            type="url"
            :error="save.error.value?.fieldError('confirm_sign_up_url')"
          />
          <BaseInput
            v-model="resetPasswordUrl"
            label="Reset password page"
            type="url"
            :error="save.error.value?.fieldError('reset_password_url')"
          />
          <BaseInput
            v-model="acceptInvitationUrl"
            label="Accept invitation page"
            type="url"
            :error="save.error.value?.fieldError('accept_invitation_url')"
          />
        </BaseCard>
      </fieldset>

      <div v-if="access.admin" class="flex flex-wrap items-center gap-2">
        <BaseButton type="submit" label="Save changes" :loading="save.loading.value" :disabled="!dirty" />
        <BaseButton v-if="dirty" label="Discard changes" variant="secondary" @click="reset(project)" />
        <span v-if="dirty" class="text-sm text-text-muted" role="status">Unsaved changes</span>
      </div>
    </form>

    <BaseCard v-if="access.accountAdmin" title="Delete project" description="Deletes the project with all of its end users, applications and settings.">
      <BaseButton label="Delete project" variant="danger" class="self-start" @click="deleteOpen = true" />
    </BaseCard>

    <ConfirmDialog
      v-model:visible="deleteOpen"
      title="Delete project?"
      confirm-label="Delete project"
      danger
      :loading="destroy.loading.value"
      :error="destroy.error.value"
      @confirm="destroy.run()"
    >
      <p>
        This permanently deletes <strong>{{ project.name }}</strong>: its end users, groups, applications, identity providers,
        attributes, signing keys and certificates. Apps using it will stop working. This can't be undone.
      </p>
    </ConfirmDialog>
  </template>
</template>
