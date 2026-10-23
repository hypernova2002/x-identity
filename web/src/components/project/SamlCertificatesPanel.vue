<script setup lang="ts">
import { computed, onMounted } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useSamlIdentityProvider } from '@/composables/useSamlIdentityProvider'
import type { SamlCertificate } from '@/types/api'
import { formatDateTime } from '@/utils/format'

const props = defineProps<{
  accountUid: string
  projectUid: string
  projectName: string
  canManage: boolean
}>()

const { info, load, certificateAction } = useSamlIdentityProvider()
const statusLabel: Record<SamlCertificate['status'], string> = { active: 'Signing now', next: 'Published, not used yet', retired: 'Retired, still published' }
const hasNext = computed(() => info.value?.certificates.some((certificate) => certificate.status === 'next') ?? false)

function download(certificate: SamlCertificate) {
  const link = document.createElement('a')
  link.href = URL.createObjectURL(new Blob([certificate.certificate], { type: 'application/x-pem-file' }))
  link.download = `${props.projectName}-saml-${certificate.status}.pem`
  link.click()
  URL.revokeObjectURL(link.href)
}

onMounted(() => load.run(props.accountUid, props.projectUid))
</script>

<template>
  <BaseCard
    title="SAML signing certificates"
    description="Sign SAML responses to SAML applications, logout messages, and requests to companies' SAML identity providers."
  >
    <BaseAlert v-if="load.error.value" variant="danger">We couldn't load the certificates. {{ load.error.value.message }}</BaseAlert>
    <BaseAlert v-if="certificateAction.error.value" variant="danger">{{ certificateAction.error.value.message }}</BaseAlert>
    <p v-if="load.loading.value" class="text-sm text-text-muted" role="status">Loading certificates…</p>

    <template v-if="info">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">SAML metadata and entity ID</dt>
        <dd class="font-mono text-xs break-all">{{ info.metadata_url }}</dd>
      </dl>
      <ul class="flex flex-col divide-y divide-border">
        <li v-for="certificate in info.certificates" :key="certificate.uid" class="flex flex-wrap items-center justify-between gap-2 py-3 text-sm">
          <div class="flex flex-col gap-1">
            <StatusBadge :tone="certificate.status === 'active' ? 'success' : certificate.status === 'next' ? 'info' : 'neutral'" :label="statusLabel[certificate.status]" />
            <span class="font-mono text-xs break-all text-text-muted">SHA-256 {{ certificate.fingerprint_sha256 }}</span>
            <span class="text-xs text-text-muted">Expires {{ formatDateTime(certificate.expires_at) }}</span>
          </div>
          <div class="flex flex-wrap gap-2">
            <BaseButton label="Download" variant="secondary" size="sm" @click="download(certificate)" />
            <template v-if="canManage">
              <BaseButton
                v-if="certificate.status === 'next'"
                label="Start signing with it"
                variant="secondary"
                size="sm"
                :loading="certificateAction.loading.value"
                @click="certificateAction.run('activate', certificate)"
              />
              <BaseButton
                v-if="certificate.status !== 'active'"
                label="Remove"
                variant="ghost"
                size="sm"
                :loading="certificateAction.loading.value"
                @click="certificateAction.run('remove', certificate)"
              />
            </template>
          </div>
        </li>
      </ul>
      <p class="text-xs text-text-muted">
        To rotate: add a new certificate, give apps time to pick it up from the metadata (or upload it to them), then start signing with
        it. Remove the retired one once no app needs it.
      </p>
      <BaseAlert v-if="!canManage" variant="info">Only project and account admins can rotate certificates.</BaseAlert>
      <BaseButton
        v-else-if="!hasNext"
        label="Add new certificate"
        variant="secondary"
        size="sm"
        class="self-start"
        :loading="certificateAction.loading.value"
        @click="certificateAction.run('add')"
      />
    </template>
  </BaseCard>
</template>
