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
      <legend class="px-1 text-sm font-semibold">{{ $t('project.samlAppForm.importFromTheAppS') }}</legend>
      <BaseAlert v-if="importError" variant="danger">{{ importError.fieldError('metadata') ?? importError.fieldError('metadata_url') ?? importError.message }}</BaseAlert>
      <BaseInput v-model="metadataUrl" :label="$t('project.samlAppForm.metadataUrl')" type="url" />
      <BaseTextarea v-model="metadataXml" :label="$t('project.samlAppForm.orPasteTheMetadataXml')" monospace :rows="3" />
      <BaseButton
        :label="$t('project.samlAppForm.fillInFromMetadata')"
        variant="secondary"
        class="self-start"
        :disabled="!metadataUrl.trim() && !metadataXml.trim()"
        :loading="importing"
        @click="importMetadata"
      />
    </fieldset>

    <BaseAlert v-if="error && error.details.length === 0" variant="danger">{{ error.message }}</BaseAlert>
    <BaseInput v-model="draft.name" :label="$t('project.samlAppForm.name')" required :hint="$t('project.samlAppForm.shownInTheAppPortal')" :error="error?.fieldError('name')" />
    <BaseInput v-model="draft.entityId" :label="$t('project.samlAppForm.entityId')" required :hint="$t('project.samlAppForm.theAppSSamlIssuer')" :error="error?.fieldError('entity_id')" />
    <BaseInput
      v-model="draft.acsUrls"
      :label="$t('project.samlAppForm.assertionConsumerServiceUrls')"
      required
      :hint="$t('project.samlAppForm.whereTheAppReceivesSign')"
      :error="error?.fieldError('acs_urls')"
    />
    <BaseInput v-model="draft.sloUrl" :label="$t('project.samlAppForm.singleLogoutUrl')" type="url" :hint="$t('project.samlAppForm.optionalUsedToLogUsers')" :error="error?.fieldError('slo_url')" />
    <BaseSelect v-model="draft.nameIdFormat" :label="$t('project.samlAppForm.nameid')" :options="nameIdFormatOptions" :error="error?.fieldError('name_id_format')" />

    <fieldset class="flex flex-col gap-3">
      <legend class="mb-1 text-sm font-semibold">{{ $t('project.samlAppForm.attributes') }}</legend>
      <div v-for="(mapping, index) in draft.attributeMappings" :key="index" class="flex flex-wrap items-end gap-2">
        <div class="min-w-36 flex-1"><BaseInput v-model="mapping.name" :label="$t('project.samlAppForm.attributeName', { index: index + 1 })" /></div>
        <div class="min-w-36 flex-1"><BaseSelect v-model="mapping.source" :label="$t('project.samlAppForm.value')" :options="attributeSourceOptions" /></div>
        <div v-if="mapping.source === 'custom'" class="min-w-28 flex-1"><BaseInput v-model="mapping.customKey" :label="$t('project.samlAppForm.attributeKey')" /></div>
        <BaseButton :label="$t('project.samlAppForm.remove')" variant="ghost" size="sm" @click="removeMapping(index)" />
      </div>
      <p v-if="error?.fieldError('attribute_mappings')" class="text-xs font-medium text-danger">{{ $t('base.field.error', { message: error.fieldError('attribute_mappings') }) }}</p>
      <BaseButton :label="$t('project.samlAppForm.addAttribute')" variant="secondary" size="sm" class="self-start" @click="addMapping" />
    </fieldset>

    <fieldset class="flex flex-col gap-3">
      <legend class="mb-1 text-sm font-semibold">{{ $t('project.samlAppForm.signing') }}</legend>
      <BaseCheckbox v-model="draft.signAssertion" :label="$t('project.samlAppForm.signTheAssertion')" :hint="$t('project.samlAppForm.whatMostAppsExpect')" />
      <BaseCheckbox v-model="draft.signResponse" :label="$t('project.samlAppForm.signTheWholeResponse')" />
      <BaseCheckbox v-model="draft.requireSignedRequests" :label="$t('project.samlAppForm.requireSignedRequestsFromThe')" :hint="$t('project.samlAppForm.needsTheAppSCertificate')" />
      <BaseTextarea
        v-model="draft.spCertificate"
        :label="$t('project.samlAppForm.appSSigningCertificate')"
        monospace
        :rows="4"
        :hint="$t('project.samlAppForm.optionalPemUsedToCheck')"
        :error="error?.fieldError('sp_certificate') ?? error?.fieldError('require_signed_requests')"
      />
    </fieldset>

    <BaseInput
      v-model="draft.defaultRelayState"
      :label="$t('project.samlAppForm.defaultRelayState')"
      :hint="$t('project.samlAppForm.optionalSentWhenTheApp')"
      :error="error?.fieldError('default_relay_state')"
    />
  </form>
</template>
