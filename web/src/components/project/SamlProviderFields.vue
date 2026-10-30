<script setup lang="ts">
import { ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSearchSelect from '@/components/base/BaseSearchSelect.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTextarea from '@/components/base/BaseTextarea.vue'
import { useProjectLookups } from '@/composables/useProjectLookups'
import type { ApiError } from '@/services/http'
import type { IdentityProviderDraft } from '@/utils/identityProviders'
import { nameIdFormatOptions } from '@/utils/samlApps'

defineProps<{
  error: ApiError | null
  importError: ApiError | null
  importing: boolean
}>()

const emit = defineEmits<{
  importMetadata: [source: { metadata_xml: string } | { metadata_url: string }]
}>()

const draft = defineModel<IdentityProviderDraft>({ required: true })

const metadataUrl = ref('')
const metadataXml = ref('')
const lookups = useProjectLookups()

function importMetadata() {
  emit('importMetadata', metadataUrl.value.trim() ? { metadata_url: metadataUrl.value.trim() } : { metadata_xml: metadataXml.value })
}

function addMapping() {
  draft.value.groupMappings.push({ value: '', groupUid: '' })
}
</script>

<template>
  <fieldset class="flex flex-col gap-3 rounded-md border border-border p-4">
    <legend class="px-1 text-sm font-semibold">{{ $t('project.samlProviderFields.importFromTheIdentityProvider') }}</legend>
    <BaseAlert v-if="importError" variant="danger">
      {{ importError.fieldError('metadata') ?? importError.fieldError('metadata_url') ?? importError.message }}
    </BaseAlert>
    <BaseInput v-model="metadataUrl" :label="$t('project.samlProviderFields.metadataUrl')" type="url" />
    <BaseTextarea v-model="metadataXml" :label="$t('project.samlProviderFields.orPasteTheMetadataXml')" monospace :rows="3" />
    <BaseButton
      :label="$t('project.samlProviderFields.fillInFromMetadata')"
      variant="secondary"
      class="self-start"
      :disabled="!metadataUrl.trim() && !metadataXml.trim()"
      :loading="importing"
      @click="importMetadata"
    />
  </fieldset>

  <BaseInput v-model="draft.samlEntityId" :label="$t('project.samlProviderFields.identityProviderEntityId')" required :error="error?.fieldError('saml_idp_entity_id')" />
  <BaseInput v-model="draft.samlSsoUrl" :label="$t('project.samlProviderFields.signOnUrl')" type="url" required :hint="$t('project.samlProviderFields.httpRedirectBinding')" :error="error?.fieldError('saml_sso_url')" />
  <BaseInput
    v-model="draft.samlSloUrl"
    :label="$t('project.samlProviderFields.logoutUrl')"
    type="url"
    :hint="$t('project.samlProviderFields.optionalLoggingOutAlsoLogs')"
    :error="error?.fieldError('saml_slo_url')"
  />
  <BaseTextarea
    v-model="draft.samlCertificates"
    :label="$t('project.samlProviderFields.signingCertificates')"
    monospace
    :rows="5"
    required
    :hint="$t('project.samlProviderFields.pemPasteMoreThanOne')"
    :error="error?.fieldError('saml_idp_certificates')"
  />

  <BaseInput
    v-model="draft.domains"
    :label="$t('project.samlProviderFields.emailDomains')"
    :hint="$t('project.samlProviderFields.separateSeveralWithCommasE')"
    :error="error?.fieldError('domains')"
  />

  <fieldset class="flex flex-col gap-3">
    <legend class="mb-1 text-sm font-semibold">{{ $t('project.samlProviderFields.whatTheProviderSends') }}</legend>
    <BaseSelect v-model="draft.samlNameIdFormat" :label="$t('project.samlProviderFields.nameidToRequest')" :options="nameIdFormatOptions" />
    <div class="grid gap-4 sm:grid-cols-3">
      <BaseInput v-model="draft.samlEmailAttribute" :label="$t('project.samlProviderFields.emailAttribute')" :hint="$t('project.samlProviderFields.emptyTheNameid')" :error="error?.fieldError('saml_email_attribute')" />
      <BaseInput v-model="draft.samlNameAttribute" :label="$t('project.samlProviderFields.nameAttribute')" :error="error?.fieldError('saml_name_attribute')" />
      <BaseInput v-model="draft.samlGroupsAttribute" :label="$t('project.samlProviderFields.groupsAttribute')" :error="error?.fieldError('saml_groups_attribute')" />
    </div>
  </fieldset>

  <fieldset class="flex flex-col gap-3">
    <legend class="mb-1 text-sm font-semibold">{{ $t('project.samlProviderFields.groupMappings') }}</legend>
    <p class="text-xs text-text-muted">
      {{ $t('project.samlProviderFields.atEachSignInMembership') }}
    </p>
    <div v-for="(mapping, index) in draft.groupMappings" :key="index" class="flex flex-wrap items-end gap-2">
      <div class="min-w-36 flex-1"><BaseInput v-model="mapping.value" :label="$t('project.samlProviderFields.providerGroup', { index: index + 1 })" /></div>
      <div class="min-w-36 flex-1">
        <BaseSearchSelect
          v-model="mapping.groupUid"
          :label="$t('project.samlProviderFields.projectGroup')"
          :search="lookups.searchGroups"
          :resolve-label="lookups.groupName"
          :see-all="lookups.allGroups.value"
        />
      </div>
      <BaseButton :label="$t('project.samlProviderFields.remove')" variant="ghost" size="sm" @click="draft.groupMappings.splice(index, 1)" />
    </div>
    <p v-if="error?.fieldError('group_mappings')" class="text-xs font-medium text-danger">{{ $t('base.field.error', { message: error.fieldError('group_mappings') }) }}</p>
    <BaseButton :label="$t('project.samlProviderFields.addMapping')" variant="secondary" size="sm" class="self-start" @click="addMapping" />
  </fieldset>

  <BaseCheckbox
    v-model="draft.allowIdpInitiated"
    :label="$t('project.samlProviderFields.allowSignInStartedFrom')"
    :hint="$t('project.samlProviderFields.usersCanOpenTheApp')"
  />
</template>
