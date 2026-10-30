<script setup lang="ts">
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseTextarea from '@/components/base/BaseTextarea.vue'
import SamlProviderFields from '@/components/project/SamlProviderFields.vue'
import type { ApiError } from '@/services/http'
import type { IdentityProvider } from '@/types/api'
import type { IdentityProviderDraft } from '@/utils/identityProviders'

defineProps<{
  formId: string
  /** The provider being edited; null when adding one. */
  existing: IdentityProvider | null
  error: ApiError | null
  /** For SAML group mappings. */
  importError: ApiError | null
  importing: boolean
}>()

const emit = defineEmits<{
  submit: []
  importMetadata: [source: { metadata_xml: string } | { metadata_url: string }]
}>()

const draft = defineModel<IdentityProviderDraft>({ required: true })
</script>

<template>
  <form :id="formId" class="flex flex-col gap-4" novalidate @submit.prevent="emit('submit')">
    <BaseAlert v-if="error && error.details.length === 0" variant="danger">{{ error.message }}</BaseAlert>

    <BaseInput v-model="draft.name" :label="$t('project.identityProviderForm.name')" required :hint="$t('project.identityProviderForm.shownToEndUsersE')" :error="error?.fieldError('name')" />

    <SamlProviderFields
      v-if="draft.kind === 'saml'"
      v-model="draft"
      :error="error"
      :import-error="importError"
      :importing="importing"
      @import-metadata="(source) => emit('importMetadata', source)"
    />

    <template v-else>
    <BaseInput
      v-if="draft.kind === 'oidc'"
      v-model="draft.discoveryUrl"
      :label="$t('project.identityProviderForm.issuerOrDiscoveryUrl')"
      type="url"
      required
      :hint="$t('project.identityProviderForm.forExampleHttpsLoginExample')"
      :error="error?.fieldError('discovery_url')"
    />

    <BaseInput
      v-model="draft.clientId"
      :label="draft.kind === 'apple' ? $t('project.identityProviderForm.servicesId') : $t('project.identityProviderForm.clientId')"
      required
      :hint="draft.kind === 'apple' ? $t('project.identityProviderForm.theIdentifierOfTheServices') : $t('project.identityProviderForm.fromTheProviderSApp')"
      :error="error?.fieldError('client_id')"
    />

    <BaseInput
      v-if="draft.kind !== 'apple'"
      v-model="draft.clientSecret"
      :label="$t('project.identityProviderForm.clientSecret')"
      type="password"
      autocomplete="off"
      :required="!existing"
      :hint="existing?.client_secret_set ? $t('project.identityProviderForm.aSecretIsSavedLeave') : undefined"
      :error="error?.fieldError('client_secret')"
    />

    <template v-if="draft.kind === 'apple'">
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput v-model="draft.appleTeamId" :label="$t('project.identityProviderForm.teamId')" required :error="error?.fieldError('apple_team_id')" />
        <BaseInput v-model="draft.appleKeyId" :label="$t('project.identityProviderForm.keyId')" required :error="error?.fieldError('apple_key_id')" />
      </div>
      <BaseTextarea
        v-model="draft.applePrivateKey"
        :label="$t('project.identityProviderForm.privateKeyP8')"
        monospace
        :rows="5"
        :required="!existing"
        :hint="
          existing?.apple_private_key_set
            ? $t('project.identityProviderForm.aKeyIsSavedPaste')
            : $t('project.identityProviderForm.pasteTheWholeFileFrom')
        "
        :error="error?.fieldError('apple_private_key')"
      />
    </template>

    <BaseInput
      v-else
      v-model="draft.scopes"
      :label="$t('project.identityProviderForm.scopes')"
      :hint="$t('project.identityProviderForm.separatedBySpacesMustInclude')"
      :error="error?.fieldError('scopes')"
    />

    <BaseInput
      v-model="draft.additionalAudiences"
      :label="$t('project.identityProviderForm.nativeAppClientIds')"
      :hint="
        draft.kind === 'apple'
          ? $t('project.identityProviderForm.optionalYourIosAppS')
          : $t('project.identityProviderForm.optionalIosOrAndroidClient')
      "
      :error="error?.fieldError('additional_audiences')"
    />
    </template>

    <BaseCheckbox
      v-model="draft.createUsers"
      :label="$t('project.identityProviderForm.createUsersOnTheirFirst')"
      :hint="$t('project.identityProviderForm.evenWhenSelfSignUp')"
    />
  </form>
</template>
