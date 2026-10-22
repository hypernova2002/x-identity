<script setup lang="ts">
import { ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTextarea from '@/components/base/BaseTextarea.vue'
import type { ApiError } from '@/services/http'
import { attributeSourceOptions, nameIdFormatOptions, type SamlAppDraft } from '@/utils/samlApps'

defineProps<{
  formId: string
  error: ApiError | null
  importError: ApiError | null
  importing: boolean
}>()

const emit = defineEmits<{
  submit: []
  importMetadata: [source: { metadata_xml: string } | { metadata_url: string }]
}>()

const draft = defineModel<SamlAppDraft>({ required: true })

const metadataUrl = ref('')
const metadataXml = ref('')

function importMetadata() {
  emit('importMetadata', metadataUrl.value.trim() ? { metadata_url: metadataUrl.value.trim() } : { metadata_xml: metadataXml.value })
}

function addMapping() {
  draft.value.attributeMappings.push({ name: '', source: 'email', customKey: '' })
}

function removeMapping(index: number) {
  draft.value.attributeMappings.splice(index, 1)
}
</script>

<template>
  <form :id="formId" class="flex flex-col gap-4" novalidate @submit.prevent="emit('submit')">
    <fieldset class="flex flex-col gap-3 rounded-md border border-border p-4">
      <legend class="px-1 text-sm font-semibold">Import from the app's metadata</legend>
      <BaseAlert v-if="importError" variant="danger">{{ importError.fieldError('metadata') ?? importError.fieldError('metadata_url') ?? importError.message }}</BaseAlert>
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

    <BaseAlert v-if="error && error.details.length === 0" variant="danger">{{ error.message }}</BaseAlert>
    <BaseInput v-model="draft.name" label="Name" required hint="Shown in the app portal." :error="error?.fieldError('name')" />
    <BaseInput v-model="draft.entityId" label="Entity ID" required hint="The app's SAML issuer, sometimes called the audience." :error="error?.fieldError('entity_id')" />
    <BaseInput
      v-model="draft.acsUrls"
      label="Assertion consumer service URLs"
      required
      hint="Where the app receives sign-ins (HTTP-POST). The first is used when the app is opened from the portal. Separate several with commas."
      :error="error?.fieldError('acs_urls')"
    />
    <BaseInput v-model="draft.sloUrl" label="Single logout URL" type="url" hint="Optional. Used to log users out of the app (HTTP-Redirect)." :error="error?.fieldError('slo_url')" />
    <BaseSelect v-model="draft.nameIdFormat" label="NameID" :options="nameIdFormatOptions" :error="error?.fieldError('name_id_format')" />

    <fieldset class="flex flex-col gap-3">
      <legend class="mb-1 text-sm font-semibold">Attributes</legend>
      <div v-for="(mapping, index) in draft.attributeMappings" :key="index" class="flex flex-wrap items-end gap-2">
        <div class="min-w-36 flex-1"><BaseInput v-model="mapping.name" :label="`Attribute ${index + 1} name`" /></div>
        <div class="min-w-36 flex-1"><BaseSelect v-model="mapping.source" label="Value" :options="attributeSourceOptions" /></div>
        <div v-if="mapping.source === 'custom'" class="min-w-28 flex-1"><BaseInput v-model="mapping.customKey" label="Attribute key" /></div>
        <BaseButton label="Remove" variant="ghost" size="sm" @click="removeMapping(index)" />
      </div>
      <p v-if="error?.fieldError('attribute_mappings')" class="text-xs font-medium text-danger">Error: {{ error.fieldError('attribute_mappings') }}</p>
      <BaseButton label="Add attribute" variant="secondary" size="sm" class="self-start" @click="addMapping" />
    </fieldset>

    <fieldset class="flex flex-col gap-3">
      <legend class="mb-1 text-sm font-semibold">Signing</legend>
      <BaseCheckbox v-model="draft.signAssertion" label="Sign the assertion" hint="What most apps expect." />
      <BaseCheckbox v-model="draft.signResponse" label="Sign the whole response" />
      <BaseCheckbox v-model="draft.requireSignedRequests" label="Require signed requests from the app" hint="Needs the app's certificate below." />
      <BaseTextarea
        v-model="draft.spCertificate"
        label="App's signing certificate"
        monospace
        :rows="4"
        hint="Optional. PEM. Used to check the app's signed sign-in and logout requests."
        :error="error?.fieldError('sp_certificate') ?? error?.fieldError('require_signed_requests')"
      />
    </fieldset>

    <BaseInput
      v-model="draft.defaultRelayState"
      label="Default relay state"
      hint="Optional. Sent when the app is opened from the portal, e.g. the page to show first."
      :error="error?.fieldError('default_relay_state')"
    />
  </form>
</template>
