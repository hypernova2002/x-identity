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
    <BaseAlert v-if="saved && !dirty" variant="success">{{ $t('project.appClientSignIn.signInSettingsSaved') }}</BaseAlert>
    <BaseAlert v-if="!access.developer" variant="info">{{ $t('project.appClientSignIn.onlyProjectAdminsAndDevelopers') }}</BaseAlert>
    <BaseAlert v-if="save.error.value && save.error.value.details.length === 0" variant="danger">{{ save.error.value.message }}</BaseAlert>

    <fieldset :disabled="!access.developer" class="contents">
      <BaseCard :title="$t('project.appClientSignIn.name')">
        <BaseInput v-model="name" :label="$t('project.appClientSignIn.name')" required :hint="$t('project.appClientSignIn.shownInTheAppPortal')" :error="save.error.value?.fieldError('name')" />
      </BaseCard>

      <BaseCard :title="$t('project.appClientSignIn.redirects')" :description="$t('project.appClientSignIn.matchedExactlyHttpsUrlsHttp')">
        <BaseTextarea
          v-model="redirectUris"
          :label="$t('project.appClientSignIn.redirectUris')"
          monospace
          :rows="3"
          :hint="$t('project.appClientSignIn.whereUsersReturnAfterSigning')"
          :error="save.error.value?.fieldError('redirect_uris')"
        />
        <BaseTextarea
          v-model="postLogoutUris"
          :label="$t('project.appClientSignIn.postLogoutRedirectUris')"
          monospace
          :rows="2"
          :hint="$t('project.appClientSignIn.whereTheAppMaySend')"
          :error="save.error.value?.fieldError('post_logout_redirect_uris')"
        />
      </BaseCard>

      <BaseCard :title="$t('project.appClientSignIn.browserAccess')">
        <BaseTextarea
          v-model="origins"
          :label="$t('project.appClientSignIn.allowedOrigins')"
          monospace
          :rows="2"
          :hint="$t('project.appClientSignIn.browserAppsOnlyOriginsThat')"
          :error="save.error.value?.fieldError('allowed_origins')"
        />
      </BaseCard>

      <BaseCard :title="$t('project.appClientSignIn.appPortal')">
        <BaseInput
          v-model="launchUrl"
          :label="$t('project.appClientSignIn.launchUrl')"
          type="url"
          :hint="$t('project.appClientSignIn.optionalWhereTheAppPortal')"
          :error="save.error.value?.fieldError('launch_url')"
        />
      </BaseCard>
    </fieldset>

    <div v-if="access.developer" class="flex flex-wrap items-center gap-2">
      <BaseButton type="submit" :label="$t('project.appClientSignIn.saveChanges')" :loading="save.loading.value" :disabled="!dirty" />
      <BaseButton v-if="dirty" :label="$t('project.appClientSignIn.discardChanges')" variant="secondary" @click="reset" />
      <span v-if="dirty" class="text-sm text-text-muted" role="status">{{ $t('project.appClientSignIn.unsavedChanges') }}</span>
    </div>
  </form>
</template>
