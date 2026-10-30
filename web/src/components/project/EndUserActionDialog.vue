<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import type { EndUserAction } from '@/composables/useEndUserActions'
import type { ApiError } from '@/services/http'
import type { EndUser } from '@/types/api'

const { t } = useI18n()

const props = defineProps<{
  pending: { action: EndUserAction; endUser: EndUser } | null
  loading: boolean
  error: ApiError | null
}>()

const emit = defineEmits<{
  confirm: []
  cancel: []
}>()

const copy: Partial<Record<EndUserAction, { title: string; confirm: string; body: string }>> = {
  disable: {
    title: t('project.endUserActionDialog.disableThisEndUser'),
    confirm: t('project.endUserActionDialog.disable'),
    body: t('project.endUserActionDialog.theyCanTSignIn'),
  },
  reset_mfa: {
    title: t('project.endUserActionDialog.resetMfa'),
    confirm: t('project.endUserActionDialog.resetMfa2'),
    body: t('project.endUserActionDialog.turnsOffTheirMfaTheir'),
  },
  sign_out: {
    title: t('project.endUserActionDialog.signOutEverywhere'),
    confirm: t('project.endUserActionDialog.signOutEverywhere2'),
    body: t('project.endUserActionDialog.revokesEveryRefreshTokenStops'),
  },
  delete: {
    title: t('project.endUserActionDialog.deleteThisEndUser'),
    confirm: t('project.endUserActionDialog.deleteEndUser'),
    body: t('project.endUserActionDialog.permanentlyDeletesTheUserTheir'),
  },
}

const visible = computed({
  get: () => props.pending !== null,
  set: (open: boolean) => {
    if (!open) emit('cancel')
  },
})
const text = computed(() => (props.pending ? copy[props.pending.action] : undefined))
</script>

<template>
  <ConfirmDialog
    v-if="text && pending"
    v-model:visible="visible"
    :title="text.title"
    :confirm-label="text.confirm"
    danger
    :loading="loading"
    :error="error"
    @confirm="emit('confirm')"
  >
    <p><strong>{{ pending.endUser.email }}</strong></p>
    <p>{{ text.body }}</p>
  </ConfirmDialog>
</template>
