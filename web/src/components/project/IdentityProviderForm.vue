<script setup lang="ts">
import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseTextarea from '@/components/base/BaseTextarea.vue'
import SamlProviderFields from '@/components/project/SamlProviderFields.vue'
import type { ApiError } from '@/services/http'
import type { Group, IdentityProvider } from '@/types/api'
import type { IdentityProviderDraft } from '@/utils/identityProviders'

defineProps<{
  formId: string
  /** The provider being edited; null when adding one. */
  existing: IdentityProvider | null
  error: ApiError | null
  /** For SAML group mappings. */
  groups: readonly Group[]
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

    <BaseInput v-model="draft.name" label="Name" required hint="Shown to end users, e.g. on sign-in buttons." :error="error?.fieldError('name')" />

    <SamlProviderFields
      v-if="draft.kind === 'saml'"
      v-model="draft"
      :groups="groups"
      :error="error"
      :import-error="importError"
      :importing="importing"
      @import-metadata="(source) => emit('importMetadata', source)"
    />

    <template v-else>
    <BaseInput
      v-if="draft.kind === 'oidc'"
      v-model="draft.discoveryUrl"
      label="Issuer or discovery URL"
      type="url"
      required
      hint="For example https://login.example.com. Its /.well-known/openid-configuration is loaded when you save."
      :error="error?.fieldError('discovery_url')"
    />

    <BaseInput
      v-model="draft.clientId"
      :label="draft.kind === 'apple' ? 'Services ID' : 'Client ID'"
      required
      :hint="draft.kind === 'apple' ? 'The identifier of the Services ID you created for web sign-in.' : 'From the provider\'s app registration.'"
      :error="error?.fieldError('client_id')"
    />

    <BaseInput
      v-if="draft.kind !== 'apple'"
      v-model="draft.clientSecret"
      label="Client secret"
      type="password"
      autocomplete="off"
      :required="!existing"
      :hint="existing?.client_secret_set ? 'A secret is saved. Leave blank to keep it.' : undefined"
      :error="error?.fieldError('client_secret')"
    />

    <template v-if="draft.kind === 'apple'">
      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput v-model="draft.appleTeamId" label="Team ID" required :error="error?.fieldError('apple_team_id')" />
        <BaseInput v-model="draft.appleKeyId" label="Key ID" required :error="error?.fieldError('apple_key_id')" />
      </div>
      <BaseTextarea
        v-model="draft.applePrivateKey"
        label="Private key (.p8)"
        monospace
        :rows="5"
        :required="!existing"
        :hint="
          existing?.apple_private_key_set
            ? 'A key is saved. Paste a new one to replace it.'
            : 'Paste the whole file, from -----BEGIN PRIVATE KEY----- to -----END PRIVATE KEY-----.'
        "
        :error="error?.fieldError('apple_private_key')"
      />
    </template>

    <BaseInput
      v-else
      v-model="draft.scopes"
      label="Scopes"
      hint="Separated by spaces. Must include openid; email is needed to match and create users."
      :error="error?.fieldError('scopes')"
    />

    <BaseInput
      v-model="draft.additionalAudiences"
      label="Native app client IDs"
      :hint="
        draft.kind === 'apple'
          ? 'Optional. Your iOS app\'s bundle ID, so it can sign in with ID tokens from Sign in with Apple. Separate several with commas.'
          : 'Optional. iOS or Android client IDs whose ID tokens your native apps send directly. Separate several with commas.'
      "
      :error="error?.fieldError('additional_audiences')"
    />
    </template>

    <BaseCheckbox
      v-model="draft.createUsers"
      label="Create users on their first sign-in"
      hint="Even when self sign-up is off. When off, only existing or invited users can sign in with this provider unless self sign-up is on."
    />
  </form>
</template>
