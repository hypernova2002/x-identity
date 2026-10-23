<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseTextarea from '@/components/base/BaseTextarea.vue'
import { useAppClient } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { useUnsavedChanges } from '@/composables/useUnsavedChanges'
import { projectAdminService } from '@/services/project'
import type { AppClient } from '@/types/api'
import { parseList } from '@/utils/format'

const { accountUid, project, access } = useProjectContext()
const { record: client, replace } = useAppClient()

const name = ref('')
const origins = ref('')
const redirectUris = ref('')
const postLogoutUris = ref('')
const launchUrl = ref('')
const saved = ref(false)

const form = computed(() => ({
  name: name.value,
  allowed_origins: parseList(origins.value),
  redirect_uris: parseList(redirectUris.value),
  post_logout_redirect_uris: parseList(postLogoutUris.value),
  launch_url: launchUrl.value.trim() || null,
}))

const current = (value: AppClient) => ({
  name: value.name,
  allowed_origins: value.allowed_origins,
  redirect_uris: value.redirect_uris,
  post_logout_redirect_uris: value.post_logout_redirect_uris,
  launch_url: value.launch_url,
})

const dirty = computed(() => JSON.stringify(form.value) !== JSON.stringify(current(client.value)))
useUnsavedChanges(dirty)

function reset() {
  name.value = client.value.name
  origins.value = client.value.allowed_origins.join('\n')
  redirectUris.value = client.value.redirect_uris.join('\n')
  postLogoutUris.value = client.value.post_logout_redirect_uris.join('\n')
  launchUrl.value = client.value.launch_url ?? ''
}

watch(client, reset, { immediate: true })

const save = useAsyncAction(async () => {
  if (!project.value) return
  saved.value = false
  replace(await projectAdminService.updateAppClient(accountUid.value, project.value.uid, client.value.uid, form.value))
  saved.value = true
})
</script>

<template>
  <form class="flex flex-col gap-6" novalidate @submit.prevent="save.run()">
    <BaseAlert v-if="saved && !dirty" variant="success">Sign-in settings saved.</BaseAlert>
    <BaseAlert v-if="!access.developer" variant="info">Only project admins and developers can change applications.</BaseAlert>
    <BaseAlert v-if="save.error.value && save.error.value.details.length === 0" variant="danger">{{ save.error.value.message }}</BaseAlert>

    <fieldset :disabled="!access.developer" class="contents">
      <BaseCard title="Name">
        <BaseInput v-model="name" label="Name" required hint="Shown in the app portal and the audit log." :error="save.error.value?.fieldError('name')" />
      </BaseCard>

      <BaseCard title="Redirects" description="Matched exactly. https URLs, http://localhost URLs, or app schemes like com.example.shop:/callback. One per line.">
        <BaseTextarea
          v-model="redirectUris"
          label="Redirect URIs"
          monospace
          :rows="3"
          hint="Where users return after signing in through hosted login or an identity provider."
          :error="save.error.value?.fieldError('redirect_uris')"
        />
        <BaseTextarea
          v-model="postLogoutUris"
          label="Post-logout redirect URIs"
          monospace
          :rows="2"
          hint="Where the app may send users after logging out of hosted login."
          :error="save.error.value?.fieldError('post_logout_redirect_uris')"
        />
      </BaseCard>

      <BaseCard title="Browser access">
        <BaseTextarea
          v-model="origins"
          label="Allowed origins"
          monospace
          :rows="2"
          hint="Browser apps only: origins that may call the API, e.g. https://shop.example.com, without a path. One per line."
          :error="save.error.value?.fieldError('allowed_origins')"
        />
      </BaseCard>

      <BaseCard title="App portal">
        <BaseInput
          v-model="launchUrl"
          label="Launch URL"
          type="url"
          hint="Optional. Where the app portal opens this app. Apps without one aren't listed in the portal."
          :error="save.error.value?.fieldError('launch_url')"
        />
      </BaseCard>
    </fieldset>

    <div v-if="access.developer" class="flex flex-wrap items-center gap-2">
      <BaseButton type="submit" label="Save changes" :loading="save.loading.value" :disabled="!dirty" />
      <BaseButton v-if="dirty" label="Discard changes" variant="secondary" @click="reset" />
      <span v-if="dirty" class="text-sm text-text-muted" role="status">Unsaved changes</span>
    </div>
  </form>
</template>
