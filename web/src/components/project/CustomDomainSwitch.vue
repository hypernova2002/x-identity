<script setup lang="ts">
import { computed, ref } from 'vue'
import { RouterLink } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import type { ApiError } from '@/services/http'

const props = defineProps<{
  /** A SAML app, or a SAML identity provider: who has to update their settings after a switch. */
  kind: 'app' | 'provider'
  name: string
  onCustomDomain: boolean
  /** The project's verified custom domain, or null without one. */
  domain: string | null
  projectUid: string
  canChange: boolean
  saving: boolean
  error: ApiError | null
}>()

const emit = defineEmits<{
  change: [onCustomDomain: boolean]
}>()

const confirmOpen = ref(false)

const usesDomain = computed(() => props.onCustomDomain && props.domain !== null)
const target = computed(() => (usesDomain.value ? 'the standard URLs' : props.domain))
const urls = computed(() => (props.kind === 'app' ? 'entity ID, sign-on and logout URLs' : 'service provider entity ID, ACS and logout URLs'))
const followUp = computed(() =>
  props.kind === 'app'
    ? `Sign-ins to ${props.name} fail until it has the new details: re-import the metadata in ${props.name}, or update its settings.`
    : `Sign-ins through ${props.name} fail until it has the new details: send the new metadata URL to its identity provider admin.`,
)

function confirm() {
  emit('change', !usesDomain.value)
}

defineExpose({ close: () => (confirmOpen.value = false) })
</script>

<template>
  <BaseCard title="Domain">
    <p class="text-sm">
      <template v-if="usesDomain">Uses the project's custom domain, <strong>{{ domain }}</strong>.</template>
      <template v-else-if="onCustomDomain">
        Set to use the project's custom domain, but the project has no verified domain, so it uses the standard URLs.
      </template>
      <template v-else>Uses the project's standard URLs.</template>
    </p>
    <p v-if="!domain && !onCustomDomain" class="text-sm text-text-muted">
      To use your own domain, add one in
      <RouterLink :to="{ name: 'project-domain', params: { projectUid } }" class="font-medium text-primary underline">Project settings › Custom domain</RouterLink>.
    </p>
    <BaseButton
      v-if="canChange && (domain || onCustomDomain)"
      :label="usesDomain || !domain ? 'Switch to the standard URLs' : `Switch to ${domain}`"
      variant="secondary"
      class="self-start"
      @click="confirmOpen = true"
    />
  </BaseCard>

  <ConfirmDialog
    v-model:visible="confirmOpen"
    :title="`Switch ${name} to ${target ?? 'the standard URLs'}?`"
    confirm-label="Switch"
    :loading="saving"
    :error="error"
    @confirm="confirm"
  >
    <BaseAlert variant="warning" title="The other side needs updating">
      The {{ urls }} change to {{ target ?? 'the standard URLs' }}'s. {{ followUp }}
    </BaseAlert>
  </ConfirmDialog>
</template>
