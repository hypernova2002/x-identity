<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

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
    notice.value = `${passkey.name} added. You can use it to sign in.`
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
    title="Passkeys"
    description="Sign in with your fingerprint, face or device PIN instead of a password. Passkeys can't be phished or reused, and count as multi-factor authentication."
  >
    <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>
    <BaseAlert v-if="addError" variant="danger">
      {{ addError }}
      <BaseButton v-if="needsSignIn" label="Sign in again" variant="ghost" size="sm" @click="emit('reauthenticate')" />
    </BaseAlert>
    <BaseAlert v-if="passkeys.error.value" variant="danger">
      We couldn't load your passkeys. {{ passkeys.error.value.message }}
      <BaseButton label="Try again" variant="ghost" size="sm" @click="passkeys.reload()" />
    </BaseAlert>

    <p v-if="passkeys.loading.value && !passkeys.data.value" class="text-sm text-text-muted" role="status">Loading…</p>
    <p v-else-if="passkeys.data.value?.length === 0" class="text-sm text-text-muted">You haven't added a passkey yet.</p>
    <ul v-else-if="passkeys.data.value" class="flex flex-col divide-y divide-border rounded-lg border border-border">
      <li v-for="passkey in passkeys.data.value" :key="passkey.uid" class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 text-sm">
        <div class="flex min-w-0 flex-col gap-1">
          <span class="flex flex-wrap items-center gap-2">
            <span class="font-medium break-all">{{ passkey.name }}</span>
            <StatusBadge :tone="passkey.synced ? 'info' : 'neutral'" :label="passkey.synced ? 'Synced' : 'This device or key only'" />
            <StatusBadge v-if="passkey.domain !== here" tone="warning" :label="`Only works on ${passkey.domain}`" />
          </span>
          <span class="text-xs text-text-muted">
            Added {{ formatDateTime(passkey.created_at) }} · {{ passkey.last_used_at ? `Last used ${formatDateTime(passkey.last_used_at)}` : 'Not used yet' }}
          </span>
        </div>
        <div class="flex gap-2">
          <BaseButton label="Rename" variant="ghost" size="sm" :aria-label="`Rename ${passkey.name}`" @click="startRename(passkey)" />
          <BaseButton label="Remove" variant="ghost" size="sm" :aria-label="`Remove ${passkey.name}`" @click="removing = passkey" />
        </div>
      </li>
    </ul>

    <template v-if="available">
      <BaseButton v-if="supported" label="Add a passkey" class="self-start" :loading="addPasskey.loading.value" @click="addPasskey.run()" />
      <p v-else class="text-sm text-text-muted">This browser doesn't support passkeys. Try another browser or device.</p>
    </template>
    <p v-else class="text-sm text-text-muted">Passkeys are turned off here. You can still remove the ones you have.</p>
  </BaseCard>

  <BaseDialog :visible="renaming !== null" title="Rename passkey" @update:visible="(open: boolean) => !open && (renaming = null)">
    <form class="flex flex-col gap-4" novalidate @submit.prevent="rename.run()">
      <BaseInput v-model="newName" label="Name" :error="rename.error.value?.fieldError('name')" />
      <BaseAlert v-if="rename.error.value && !rename.error.value.fieldError('name')" variant="danger">{{ rename.error.value.message }}</BaseAlert>
      <div class="flex justify-end gap-2">
        <BaseButton label="Cancel" variant="secondary" @click="renaming = null" />
        <BaseButton type="submit" label="Save" :loading="rename.loading.value" :disabled="newName.trim() === ''" />
      </div>
    </form>
  </BaseDialog>

  <ConfirmDialog
    :visible="removing !== null"
    :title="`Remove ${removing?.name ?? 'passkey'}?`"
    confirm-label="Remove passkey"
    danger
    :loading="remove.loading.value"
    :error="remove.error.value"
    @update:visible="(open: boolean) => !open && (removing = null)"
    @confirm="remove.run()"
  >
    <p>You won't be able to sign in with it any more. Remove it from your device or password manager too.</p>
  </ConfirmDialog>
</template>
