<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectService } from '@/services/account'
import { useProjectStore } from '@/stores/project'

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

watch(
  project,
  (value) => {
    if (!value) return
    name.value = value.name
    allowSelfSignUp.value = value.allow_self_sign_up
    confirmSignUpUrl.value = value.confirm_sign_up_url ?? ''
    resetPasswordUrl.value = value.reset_password_url ?? ''
    acceptInvitationUrl.value = value.accept_invitation_url ?? ''
  },
  { immediate: true },
)

const save = useAsyncAction(async () => {
  if (!project.value) return
  saved.value = false
  const updated = await projectService.update(accountUid.value, project.value.uid, {
    name: name.value,
    allow_self_sign_up: allowSelfSignUp.value,
    confirm_sign_up_url: confirmSignUpUrl.value.trim() || null,
    reset_password_url: resetPasswordUrl.value.trim() || null,
    accept_invitation_url: acceptInvitationUrl.value.trim() || null,
  })
  projectStore.upsert(updated)
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
    <BaseCard title="Endpoints" description="What your apps need to sign end users in and verify their tokens.">
      <dl class="grid gap-4 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">API base URL and token issuer (iss)</dt>
        <dd class="font-mono text-xs break-all">{{ project.token_issuer }}</dd>
        <dt class="font-medium">OpenID Connect discovery</dt>
        <dd class="font-mono text-xs break-all">{{ project.token_issuer }}/.well-known/openid-configuration</dd>
        <dt class="font-medium">JWKS</dt>
        <dd class="font-mono text-xs break-all">{{ project.token_issuer }}/.well-known/jwks.json</dd>
      </dl>
      <p class="text-sm text-text-muted">
        Any OpenID Connect library can sign users in with hosted login: point it at the issuer, and use an app client's ID with one
        of its redirect URIs. The authorization code flow with PKCE is required.
      </p>
    </BaseCard>

    <BaseCard title="Settings">
      <form class="flex flex-col gap-4" novalidate @submit.prevent="save.run()">
        <BaseAlert v-if="saved" variant="success">Settings saved.</BaseAlert>
        <BaseAlert v-if="!access.admin" variant="info">Only project and account admins can change these settings.</BaseAlert>
        <BaseAlert v-if="save.error.value && save.error.value.details.length === 0" variant="danger">{{ save.error.value.message }}</BaseAlert>

        <BaseInput v-model="name" label="Project name" required :disabled="!access.admin" :error="save.error.value?.fieldError('name')" />
        <BaseCheckbox
          v-model="allowSelfSignUp"
          label="Allow self sign-up"
          hint="When off, only admins can create end users."
          :disabled="!access.admin"
        />

        <fieldset class="flex flex-col gap-4">
          <legend class="text-sm font-semibold">Email links</legend>
          <p class="text-sm text-text-muted">
            Emails always include a 6-digit code. Add a page in your app to also include a link; use
            <code class="font-mono">{token}</code> where the link's token goes, e.g.
            <code class="font-mono">https://shop.example.com/confirm?token={token}</code>.
          </p>
          <BaseInput
            v-model="confirmSignUpUrl"
            label="Confirm sign-up page"
            type="url"
            :disabled="!access.admin"
            :error="save.error.value?.fieldError('confirm_sign_up_url')"
          />
          <BaseInput
            v-model="resetPasswordUrl"
            label="Reset password page"
            type="url"
            :disabled="!access.admin"
            :error="save.error.value?.fieldError('reset_password_url')"
          />
          <BaseInput
            v-model="acceptInvitationUrl"
            label="Accept invitation page"
            type="url"
            :disabled="!access.admin"
            :error="save.error.value?.fieldError('accept_invitation_url')"
          />
        </fieldset>

        <BaseButton v-if="access.admin" type="submit" label="Save settings" :loading="save.loading.value" class="self-start" />
      </form>
    </BaseCard>

    <BaseCard v-if="access.accountAdmin" title="Delete project" description="Deletes the project with all of its end users and app clients.">
      <BaseButton label="Delete project" variant="danger" class="self-start" @click="deleteOpen = true" />
    </BaseCard>

    <BaseDialog v-model:visible="deleteOpen" title="Delete project?">
      <p class="text-sm">
        This permanently deletes <strong>{{ project.name }}</strong>, its end users, app clients, attributes and signing keys.
        Apps using it will stop working. This can't be undone.
      </p>
      <BaseAlert v-if="destroy.error.value" variant="danger">{{ destroy.error.value.message }}</BaseAlert>
      <template #footer>
        <BaseButton label="Cancel" variant="secondary" @click="deleteOpen = false" />
        <BaseButton label="Delete project" variant="danger" :loading="destroy.loading.value" @click="destroy.run()" />
      </template>
    </BaseDialog>
  </template>
</template>
