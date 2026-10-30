<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import type { ApiError } from '@/services/http'

const { t } = useI18n()

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
/** The domain the URLs move to, or null for the standard URLs. */
const target = computed(() => (usesDomain.value ? null : props.domain))
const urlsChange = computed(() => {
  const kind = props.kind === 'app' ? 'app' : 'provider'
  return target.value
    ? t(`project.customDomainSwitch.${kind}UrlsChangeToDomain`, { domain: target.value })
    : t(`project.customDomainSwitch.${kind}UrlsChangeToStandard`)
})
const followUp = computed(() =>
  props.kind === 'app'
    ? t('project.customDomainSwitch.signInsToFailUntil', { name: props.name })
    : t('project.customDomainSwitch.signInsThroughFailUntil', { name: props.name }),
)

function confirm() {
  emit('change', !usesDomain.value)
}

defineExpose({ close: () => (confirmOpen.value = false) })
</script>

<template>
  <BaseCard :title="$t('project.customDomainSwitch.domain')">
    <p class="text-sm">
      <i18n-t v-if="usesDomain" keypath="project.customDomainSwitch.usesTheProjectSCustom">
        <template #domain><strong>{{ domain }}</strong></template>
      </i18n-t>
      <template v-else-if="onCustomDomain">
        {{ $t('project.customDomainSwitch.setToUseTheProject') }}
      </template>
      <template v-else>{{ $t('project.customDomainSwitch.usesTheProjectSStandard') }}</template>
    </p>
    <p v-if="!domain && !onCustomDomain" class="text-sm text-text-muted">
      <i18n-t keypath="project.customDomainSwitch.toUseYourOwnDomain">
        <template #link>
          <RouterLink :to="{ name: 'project-domain', params: { projectUid } }" class="font-medium text-primary underline">{{ $t('project.customDomainSwitch.projectSettingsCustomDomain') }}</RouterLink>
        </template>
      </i18n-t>
    </p>
    <BaseButton
      v-if="canChange && (domain || onCustomDomain)"
      :label="usesDomain || !domain ? $t('project.customDomainSwitch.switchToTheStandardUrls') : $t('project.customDomainSwitch.switchTo', { domain })"
      variant="secondary"
      class="self-start"
      @click="confirmOpen = true"
    />
  </BaseCard>

  <ConfirmDialog
    v-model:visible="confirmOpen"
    :title="target ? $t('project.customDomainSwitch.switchToDomainTitle', { name, domain: target }) : $t('project.customDomainSwitch.switchToStandardTitle', { name })"
    :confirm-label="$t('project.customDomainSwitch.switch')"
    :loading="saving"
    :error="error"
    @confirm="confirm"
  >
    <BaseAlert variant="warning" :title="$t('project.customDomainSwitch.theOtherSideNeedsUpdating')">
      {{ urlsChange }} {{ followUp }}
    </BaseAlert>
  </ConfirmDialog>
</template>
