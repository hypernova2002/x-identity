<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useAsync } from '@/composables/useAsync'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { ApiError } from '@/services/http'
import type { Passkey, PasskeyRegistrationOptions } from '@/types/api'
import { formatDateTime } from '@/utils/format'
import { createPasskey, passkeyErrorMessage, passkeysSupported, type PasskeyRegistrationJSON } from '@/utils/webauthn'

const props = defineProps<{
  /** Whether the user can add passkeys here; existing ones are shown either way. */
  available: boolean
  list: () => Promise<Passkey[]>
  options: () => Promise<PasskeyRegistrationOptions>
  add: (registrationId: string, credential: PasskeyRegistrationJSON) => Promise<Passkey>
  rename: (passkeyUid: string, name: string) => Promise<Passkey>
  remove: (passkeyUid: string) => Promise<unknown>
}>()

const emit = defineEmits<{
  /** Adding a passkey needs a recent sign-in; the page signs the user in again. */
  reauthenticate: []
}>()

const { t } = useI18n()

const passkeys = useAsync(props.list)
const notice = ref<string | null>(null)
const addError = ref<string | null>(null)
const needsSignIn = ref(false)
const renaming = ref<Passkey | null>(null)
const newName = ref('')
const removing = ref<Passkey | null>(null)

const supported = passkeysSupported()
const here = window.location.hostname
const shown = computed(() => props.available || (passkeys.data.value?.length ?? 0) > 0)

const addPasskey = useAsyncAction(async () => {
  notice.value = null
  addError.value = null
  needsSignIn.value = false
  try {
    const options = await props.options()
    const passkey = await props.add(options.registration_id, await createPasskey(options.public_key))
    notice.value = t('security.passkeys.added', { name: passkey.name })
    await passkeys.reload()
  } catch (caught) {
    if (caught instanceof ApiError) {
      needsSignIn.value = caught.code === 'reauthentication_required'
      addError.value = caught.message
    } else {
      addError.value = passkeyErrorMessage(caught)
    }
  }
})

const rename = useAsyncAction(async () => {
  if (!renaming.value) return
  await props.rename(renaming.value.uid, newName.value.trim())
  renaming.value = null
  await passkeys.reload()
})

const remove = useAsyncAction(async () => {
  if (!removing.value) return
  await props.remove(removing.value.uid)
  removing.value = null
  await passkeys.reload()
})

function startRename(passkey: Passkey) {
  newName.value = passkey.name
  renaming.value = passkey
}

onMounted(() => passkeys.reload())
</script>

<template>
  <BaseCard
    v-if="shown"
    :title="t('security.passkeys.title')"
    :description="t('security.passkeys.description')"
  >
    <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>
    <BaseAlert v-if="addError" variant="danger">
      {{ addError }}
      <BaseButton v-if="needsSignIn" :label="t('security.passkeys.signInAgain')" variant="ghost" size="sm" @click="emit('reauthenticate')" />
    </BaseAlert>
    <BaseAlert v-if="passkeys.error.value" variant="danger">
      {{ t('security.passkeys.loadFailed', { message: passkeys.error.value.message }) }}
      <BaseButton :label="t('common.actions.tryAgain')" variant="ghost" size="sm" @click="passkeys.reload()" />
    </BaseAlert>

    <p v-if="passkeys.loading.value && !passkeys.data.value" class="text-sm text-text-muted" role="status">{{ t('common.loading') }}</p>
    <p v-else-if="passkeys.data.value?.length === 0" class="text-sm text-text-muted">{{ t('security.passkeys.none') }}</p>
    <ul v-else-if="passkeys.data.value" class="flex flex-col divide-y divide-border rounded-lg border border-border">
      <li v-for="passkey in passkeys.data.value" :key="passkey.uid" class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 text-sm">
        <div class="flex min-w-0 flex-col gap-1">
          <span class="flex flex-wrap items-center gap-2">
            <span class="font-medium break-all">{{ passkey.name }}</span>
            <StatusBadge :tone="passkey.synced ? 'info' : 'neutral'" :label="passkey.synced ? t('security.passkeys.synced') : t('security.passkeys.deviceOnly')" />
            <StatusBadge v-if="passkey.domain !== here" tone="warning" :label="t('security.passkeys.onlyOn', { domain: passkey.domain })" />
          </span>
          <span class="text-xs text-text-muted">
            {{ t('security.passkeys.added_at', { date: formatDateTime(passkey.created_at) }) }} ·
            {{ passkey.last_used_at ? t('security.passkeys.lastUsed', { date: formatDateTime(passkey.last_used_at) }) : t('security.passkeys.notUsed') }}
          </span>
        </div>
        <div class="flex gap-2">
          <BaseButton :label="t('security.passkeys.rename')" variant="ghost" size="sm" :aria-label="t('security.passkeys.renameLabel', { name: passkey.name })" @click="startRename(passkey)" />
          <BaseButton :label="t('common.actions.remove')" variant="ghost" size="sm" :aria-label="t('security.passkeys.removeLabel', { name: passkey.name })" @click="removing = passkey" />
        </div>
      </li>
    </ul>

    <template v-if="available">
      <BaseButton v-if="supported" :label="t('security.passkeys.add')" class="self-start" :loading="addPasskey.loading.value" @click="addPasskey.run()" />
      <p v-else class="text-sm text-text-muted">{{ t('security.passkeys.unsupported') }}</p>
    </template>
    <p v-else class="text-sm text-text-muted">{{ t('security.passkeys.off') }}</p>
  </BaseCard>

  <BaseDialog :visible="renaming !== null" :title="t('security.passkeys.renameTitle')" @update:visible="(open: boolean) => !open && (renaming = null)">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="rename.run()">
      <BaseInput v-model="newName" :label="t('security.passkeys.name')" :error="rename.error.value?.fieldError('name')" />
      <BaseAlert v-if="rename.error.value && !rename.error.value.fieldError('name')" variant="danger">{{ rename.error.value.message }}</BaseAlert>
      <div class="flex justify-end gap-2">
        <BaseButton :label="t('common.actions.cancel')" variant="secondary" @click="renaming = null" />
        <BaseButton type="submit" :label="t('common.actions.save')" :loading="rename.loading.value" :disabled="newName.trim() === ''" />
      </div>
    </form>
  </BaseDialog>

  <ConfirmDialog
    :visible="removing !== null"
    :title="t('security.passkeys.removeTitle', { name: removing?.name ?? t('security.passkeys.removeFallback') })"
    :confirm-label="t('security.passkeys.removeConfirm')"
    danger
    :loading="remove.loading.value"
    :error="remove.error.value"
    @update:visible="(open: boolean) => !open && (removing = null)"
    @confirm="remove.run()"
  >
    <p>{{ t('security.passkeys.removeDescription') }}</p>
  </ConfirmDialog>
</template>
