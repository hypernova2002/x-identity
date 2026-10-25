<script setup lang="ts">
import { computed } from 'vue'

import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import type { EndUserAction } from '@/composables/useEndUserActions'
import type { ApiError } from '@/services/http'
import type { EndUser } from '@/types/api'

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
    title: 'Disable this end user?',
    confirm: 'Disable',
    body: 'They can\'t sign in, and every session is ended: refresh tokens are revoked, access tokens stop working and hosted login sessions end. Enable them again at any time.',
  },
  reset_mfa: {
    title: 'Reset MFA?',
    confirm: 'Reset MFA',
    body: 'Turns off their MFA: their authenticator, recovery codes and passkeys are deleted. Their sessions and password aren\'t changed. If the project requires MFA, they set it up again at their next sign-in.',
  },
  sign_out: {
    title: 'Sign out everywhere?',
    confirm: 'Sign out everywhere',
    body: 'Revokes every refresh token, stops their current access tokens working and ends their hosted login sessions. Their account and credentials aren\'t changed; they can sign in again.',
  },
  delete: {
    title: 'Delete this end user?',
    confirm: 'Delete end user',
    body: 'Permanently deletes the user, their sessions, MFA, linked identity providers, group memberships and app assignments. This can\'t be undone. To stop them signing in but keep the user, disable them instead.',
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
