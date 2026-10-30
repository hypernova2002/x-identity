<script setup lang="ts">
import { computed } from 'vue'

import type { MfaEnrollment } from '@/types/api'

const props = defineProps<{
  enrollment: MfaEnrollment
}>()

const qrCodeSrc = computed(() => `data:image/svg+xml;utf8,${encodeURIComponent(props.enrollment.qr_code_svg)}`)
const groupedSecret = computed(() => props.enrollment.secret.match(/.{1,4}/g)?.join(' ') ?? props.enrollment.secret)
const isToken = computed(() => props.enrollment.otp_type === 'hotp')
</script>

<template>
  <div class="flex flex-col items-center gap-4 sm:flex-row sm:items-start">
    <img
      :src="qrCodeSrc"
      :alt="isToken ? $t('auth.otpSetup.qrToken') : $t('auth.otpSetup.qrApp')"
      class="size-40 rounded-md border border-border bg-bg p-2"
    />
    <div class="flex flex-col gap-2 text-sm">
      <p v-if="isToken">{{ $t('auth.otpSetup.tokenInstructions', { digits: enrollment.digits }) }}</p>
      <p v-else>{{ $t('auth.otpSetup.appInstructions', { digits: enrollment.digits }) }}</p>
      <p class="text-text-muted">{{ $t('auth.otpSetup.cantScan') }}</p>
      <code class="rounded-sm bg-bg-subtle px-2 py-1 font-mono break-all">{{ groupedSecret }}</code>
      <p v-if="!isToken && (enrollment.digits !== 6 || enrollment.step_seconds !== 30)" class="text-xs text-text-muted">
        {{ $t('auth.otpSetup.unusualSettings', { digits: enrollment.digits, seconds: enrollment.step_seconds }) }}
      </p>
    </div>
  </div>
</template>
