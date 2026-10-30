<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import SamlAppForm from '@/components/project/SamlAppForm.vue'
import { useSamlApp } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { useUnsavedChanges } from '@/composables/useUnsavedChanges'
import { projectAdminService } from '@/services/project'
import { samlAppDraftFrom, samlAppInputFrom, withMetadata, type SamlAppDraft } from '@/utils/samlApps'

const { accountUid, project, access } = useProjectContext()
const { record: app, replace } = useSamlApp()

const draft = ref<SamlAppDraft>(samlAppDraftFrom(app.value))
const saved = ref(false)

const dirty = computed(() => JSON.stringify(samlAppInputFrom(draft.value)) !== JSON.stringify(samlAppInputFrom(samlAppDraftFrom(app.value))))
useUnsavedChanges(dirty)

watch(app, (value) => (draft.value = samlAppDraftFrom(value)))

const importMetadata = useAsyncAction(async (source: { metadata_xml: string } | { metadata_url: string }) => {
  if (!project.value) return
  draft.value = withMetadata(draft.value, await projectAdminService.parseSamlMetadata(accountUid.value, project.value.uid, source))
})

const save = useAsyncAction(async () => {
  if (!project.value) return
  saved.value = false
  replace(await projectAdminService.updateSamlApp(accountUid.value, project.value.uid, app.value.uid, samlAppInputFrom(draft.value)))
  saved.value = true
})
</script>

<template>
  <BaseCard :title="$t('project.samlAppConfiguration.signInAttributesAndSigning')" :description="$t('project.samlAppConfiguration.theAppSOwnSaml')">
    <BaseAlert v-if="saved && !dirty" variant="success">{{ $t('project.samlAppConfiguration.configurationSaved') }}</BaseAlert>
    <BaseAlert v-if="!access.developer" variant="info">{{ $t('project.samlAppConfiguration.onlyProjectAdminsAndDevelopers') }}</BaseAlert>
    <fieldset :disabled="!access.developer" class="contents">
      <SamlAppForm
        v-model="draft"
        form-id="saml-app-configuration"
        :error="save.error.value"
        :import-error="importMetadata.error.value"
        :importing="importMetadata.loading.value"
        @submit="save.run()"
        @import-metadata="(source) => importMetadata.run(source)"
      />
    </fieldset>
    <div v-if="access.developer" class="flex flex-wrap items-center gap-2">
      <BaseButton type="submit" form="saml-app-configuration" :label="$t('project.samlAppConfiguration.saveChanges')" :loading="save.loading.value" :disabled="!dirty" />
      <BaseButton v-if="dirty" :label="$t('project.samlAppConfiguration.discardChanges')" variant="secondary" @click="draft = samlAppDraftFrom(app)" />
      <span v-if="dirty" class="text-sm text-text-muted" role="status">{{ $t('project.samlAppConfiguration.unsavedChanges') }}</span>
    </div>
  </BaseCard>
</template>
