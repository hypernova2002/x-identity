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
      :alt="isToken ? 'QR code for your hardware token' : 'QR code for your authenticator app'"
      class="size-40 rounded-md border border-border bg-bg p-2"
    />
    <div class="flex flex-col gap-2 text-sm">
      <p v-if="isToken">
        Add this key to your hardware token (for example with its vendor's app), then enter the {{ enrollment.digits }}-digit code it
        shows.
      </p>
      <p v-else>Scan the QR code with an authenticator app, then enter the {{ enrollment.digits }}-digit code it shows.</p>
      <p class="text-text-muted">Can't scan it? Enter this key instead:</p>
      <code class="rounded-sm bg-bg-subtle px-2 py-1 font-mono break-all">{{ groupedSecret }}</code>
      <p v-if="!isToken && (enrollment.digits !== 6 || enrollment.step_seconds !== 30)" class="text-xs text-text-muted">
        Uses {{ enrollment.digits }} digits and {{ enrollment.step_seconds }}-second steps. Some apps, including Google and Microsoft
        Authenticator, only support 6 digits and 30 seconds.
      </p>
    </div>
  </div>
</template>
