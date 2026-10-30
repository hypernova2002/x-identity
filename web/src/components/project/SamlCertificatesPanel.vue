<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useSamlIdentityProvider } from '@/composables/useSamlIdentityProvider'
import type { SamlCertificate } from '@/types/api'
import { formatDateTime } from '@/utils/format'

const { t } = useI18n()

const props = defineProps<{
  accountUid: string
  projectUid: string
  projectName: string
  canManage: boolean
}>()

const { info, load, certificateAction } = useSamlIdentityProvider()
const statusLabel: Record<SamlCertificate['status'], string> = { active: t('project.samlCertificates.signingNow'), next: t('project.samlCertificates.publishedNotUsedYet'), retired: t('project.samlCertificates.retiredStillPublished') }
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
    :title="$t('project.samlCertificates.samlSigningCertificates')"
    :description="$t('project.samlCertificates.signSamlResponsesToSaml')"
  >
    <BaseAlert v-if="load.error.value" variant="danger">{{ $t('project.samlCertificates.loadFailed', { message: load.error.value.message }) }}</BaseAlert>
    <BaseAlert v-if="certificateAction.error.value" variant="danger">{{ certificateAction.error.value.message }}</BaseAlert>
    <p v-if="load.loading.value" class="text-sm text-text-muted" role="status">{{ $t('project.samlCertificates.loadingCertificates') }}</p>

    <template v-if="info">
      <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
        <dt class="font-medium">{{ $t('project.samlCertificates.samlMetadataAndEntityId') }}</dt>
        <dd class="font-mono text-xs break-all">{{ info.metadata_url }}</dd>
      </dl>
      <ul class="flex flex-col divide-y divide-border">
        <li v-for="certificate in info.certificates" :key="certificate.uid" class="flex flex-wrap items-center justify-between gap-2 py-3 text-sm">
          <div class="flex flex-col gap-1">
            <StatusBadge :tone="certificate.status === 'active' ? 'success' : certificate.status === 'next' ? 'info' : 'neutral'" :label="statusLabel[certificate.status]" />
            <span class="font-mono text-xs break-all text-text-muted">{{ $t('project.samlCertificates.fingerprint', { fingerprint: certificate.fingerprint_sha256 }) }}</span>
            <span class="text-xs text-text-muted">{{ $t('project.samlCertificates.expires', { date: formatDateTime(certificate.expires_at) }) }}</span>
          </div>
          <div class="flex flex-wrap gap-2">
            <BaseButton :label="$t('project.samlCertificates.download')" variant="secondary" size="sm" @click="download(certificate)" />
            <template v-if="canManage">
              <BaseButton
                v-if="certificate.status === 'next'"
                :label="$t('project.samlCertificates.startSigningWithIt')"
                variant="secondary"
                size="sm"
                :loading="certificateAction.loading.value"
                @click="certificateAction.run('activate', certificate)"
              />
              <BaseButton
                v-if="certificate.status !== 'active'"
                :label="$t('project.samlCertificates.remove')"
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
        {{ $t('project.samlCertificates.toRotateAddANew') }}
      </p>
      <BaseAlert v-if="!canManage" variant="info">{{ $t('project.samlCertificates.onlyProjectAndAccountAdmins') }}</BaseAlert>
      <BaseButton
        v-else-if="!hasNext"
        :label="$t('project.samlCertificates.addNewCertificate')"
        variant="secondary"
        size="sm"
        class="self-start"
        :loading="certificateAction.loading.value"
        @click="certificateAction.run('add')"
      />
    </template>
  </BaseCard>
</template>
