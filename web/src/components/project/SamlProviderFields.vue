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
    <legend class="px-1 text-sm font-semibold">Import from the identity provider's metadata</legend>
    <BaseAlert v-if="importError" variant="danger">
      {{ importError.fieldError('metadata') ?? importError.fieldError('metadata_url') ?? importError.message }}
    </BaseAlert>
    <BaseInput v-model="metadataUrl" label="Metadata URL" type="url" />
    <BaseTextarea v-model="metadataXml" label="Or paste the metadata XML" monospace :rows="3" />
    <BaseButton
      label="Fill in from metadata"
      variant="secondary"
      class="self-start"
      :disabled="!metadataUrl.trim() && !metadataXml.trim()"
      :loading="importing"
      @click="importMetadata"
    />
  </fieldset>

  <BaseInput v-model="draft.samlEntityId" label="Identity provider entity ID" required :error="error?.fieldError('saml_idp_entity_id')" />
  <BaseInput v-model="draft.samlSsoUrl" label="Sign-on URL" type="url" required hint="HTTP-Redirect binding." :error="error?.fieldError('saml_sso_url')" />
  <BaseInput
    v-model="draft.samlSloUrl"
    label="Logout URL"
    type="url"
    hint="Optional. Logging out also logs out at the identity provider."
    :error="error?.fieldError('saml_slo_url')"
  />
  <BaseTextarea
    v-model="draft.samlCertificates"
    label="Signing certificates"
    monospace
    :rows="5"
    required
    hint="PEM. Paste more than one while the provider rotates its certificate."
    :error="error?.fieldError('saml_idp_certificates')"
  />

  <BaseInput
    v-model="draft.domains"
    label="Email domains"
    hint="Separate several with commas, e.g. acme.com. Only addresses at these domains can sign in with this provider, and people who enter one on the sign-in page are sent here."
    :error="error?.fieldError('domains')"
  />

  <fieldset class="flex flex-col gap-3">
    <legend class="mb-1 text-sm font-semibold">What the provider sends</legend>
    <BaseSelect v-model="draft.samlNameIdFormat" label="NameID to request" :options="nameIdFormatOptions" />
    <div class="grid gap-4 sm:grid-cols-3">
      <BaseInput v-model="draft.samlEmailAttribute" label="Email attribute" hint="Empty: the NameID." :error="error?.fieldError('saml_email_attribute')" />
      <BaseInput v-model="draft.samlNameAttribute" label="Name attribute" :error="error?.fieldError('saml_name_attribute')" />
      <BaseInput v-model="draft.samlGroupsAttribute" label="Groups attribute" :error="error?.fieldError('saml_groups_attribute')" />
    </div>
  </fieldset>

  <fieldset class="flex flex-col gap-3">
    <legend class="mb-1 text-sm font-semibold">Group mappings</legend>
    <p class="text-xs text-text-muted">
      At each sign-in, membership of these project groups follows the groups attribute. Groups that aren't mapped are left alone.
    </p>
    <div v-for="(mapping, index) in draft.groupMappings" :key="index" class="flex flex-wrap items-end gap-2">
      <div class="min-w-36 flex-1"><BaseInput v-model="mapping.value" :label="`Provider group ${index + 1}`" /></div>
      <div class="min-w-36 flex-1">
        <BaseSearchSelect
          v-model="mapping.groupUid"
          label="Project group"
          :search="lookups.searchGroups"
          :resolve-label="lookups.groupName"
          :see-all="lookups.allGroups.value"
        />
      </div>
      <BaseButton label="Remove" variant="ghost" size="sm" @click="draft.groupMappings.splice(index, 1)" />
    </div>
    <p v-if="error?.fieldError('group_mappings')" class="text-xs font-medium text-danger">Error: {{ error.fieldError('group_mappings') }}</p>
    <BaseButton label="Add mapping" variant="secondary" size="sm" class="self-start" @click="addMapping" />
  </fieldset>

  <BaseCheckbox
    v-model="draft.allowIdpInitiated"
    label="Allow sign-in started from the identity provider"
    hint="Users can open the app portal from their company dashboard. Off is safer if nobody needs it."
  />
</template>
