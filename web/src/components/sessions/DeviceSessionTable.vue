<script setup lang="ts">
import { ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import type { DataTableColumn } from '@/components/base/types'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useListView } from '@/composables/useListView'
import type { Page } from '@/services/http'
import type { ListParams } from '@/services/list'
import type { DeviceSession } from '@/types/api'
import { deviceLabel, formatLocation, signInMethods } from '@/utils/deviceSessions'
import { formatDateTime } from '@/utils/format'

const props = withDefaults(
  defineProps<{
    fetchPage: (params: ListParams) => Promise<Page<DeviceSession>>
    signOut?: (session: DeviceSession) => Promise<unknown>
    /** Signs out everything but the current device; offered when given. */
    signOutOthers?: () => Promise<unknown>
    /** Whose devices these are, for messages: "you" or e.g. "casey@shop.test". */
    owner?: string
  }>(),
  { signOut: undefined, signOutOthers: undefined, owner: 'you' },
)

const columns: DataTableColumn[] = [
  { key: 'device', label: 'Device' },
  { key: 'location', label: 'Approximate location' },
  { key: 'created_at', label: 'Signed in', sortKey: 'created_at', sortKind: 'date' },
  { key: 'last_seen_at', label: 'Last active', sortKey: 'last_seen_at', sortKind: 'date' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const list = useListView(props.fetchPage, { defaultSort: '-last_seen_at', storageKey: 'device-sessions' })
const listState = list.state

const pending = ref<DeviceSession | null>(null)
const othersPending = ref(false)
const notice = ref<string | null>(null)

const signOutOne = useAsyncAction(async (session: DeviceSession) => {
  await props.signOut?.(session)
  pending.value = null
  notice.value = `${deviceLabel(session)} was signed out.`
  await list.reload()
})

const signOutRest = useAsyncAction(async () => {
  await props.signOutOthers?.()
  othersPending.value = false
  notice.value = 'Every other device was signed out.'
  await list.reload()
})

defineExpose({ reload: list.reload })
</script>

<template>
  <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>

  <BaseDataTable
    storage-key="device-sessions"
    v-model:state="listState"
    caption="Signed-in devices"
    search-placeholder="Search devices…"
    search-label="Search by device, IP address or place"
    :columns="columns"
    :rows="list.rows.value"
    :row-key="(session) => session.uid"
    :total="list.total.value"
    :per-page="list.perPage.value"
    :loading="list.loading.value"
    :error="list.error.value"
    :empty-message="owner === 'you' ? 'You aren\'t signed in on any other device.' : `${owner} isn't signed in on any device.`"
    stacked
    @reload="list.reload"
  >
    <template v-if="signOutOthers" #actions>
      <BaseButton label="Sign out all other devices" variant="secondary" @click="othersPending = true" />
    </template>
    <template #cell-device="{ row }">
      <span class="flex flex-wrap items-center gap-2">
        <span class="font-medium">{{ deviceLabel(row) }}</span>
        <StatusBadge v-if="row.current" tone="info" label="This device" />
      </span>
      <span class="block text-xs text-text-muted">{{ signInMethods(row.amr) }}</span>
    </template>
    <template #cell-location="{ row }">
      <span>{{ formatLocation(row.location) ?? 'Unknown' }}</span>
      <code v-if="row.ip" class="block font-mono text-xs text-text-muted">{{ row.ip }}</code>
    </template>
    <template #cell-created_at="{ row }"><span class="text-xs">{{ formatDateTime(row.created_at) }}</span></template>
    <template #cell-last_seen_at="{ row }"><span class="text-xs">{{ formatDateTime(row.last_seen_at) }}</span></template>
    <template #cell-actions="{ row }">
      <div class="flex sm:justify-end">
        <BaseButton
          v-if="signOut && !row.current"
          class="whitespace-nowrap"
          label="Sign out"
          variant="ghost"
          size="sm"
          :aria-label="`Sign out ${deviceLabel(row)}`"
          @click="pending = row"
        />
      </div>
    </template>
  </BaseDataTable>

  <p class="text-xs text-text-muted">
    Locations are approximate, worked out from IP addresses with
    <a href="https://db-ip.com" target="_blank" rel="noopener" class="underline">IP Geolocation by DB-IP</a>. A device stays listed until it signs
    out or its session ends.
  </p>

  <ConfirmDialog
    :visible="pending !== null"
    title="Sign out this device?"
    confirm-label="Sign out device"
    danger
    :loading="signOutOne.loading.value"
    :error="signOutOne.error.value"
    @update:visible="(open: boolean) => !open && (pending = null)"
    @confirm="pending && signOutOne.run(pending)"
  >
    <p class="text-sm">
      <strong>{{ pending ? deviceLabel(pending) : '' }}</strong> will need to sign in again. Apps on it stop being able to renew their
      sign-in; anything already signed in keeps working for a few minutes, until its access token expires.
    </p>
  </ConfirmDialog>

  <ConfirmDialog
    v-model:visible="othersPending"
    title="Sign out all other devices?"
    confirm-label="Sign out other devices"
    danger
    :loading="signOutRest.loading.value"
    :error="signOutRest.error.value"
    @confirm="signOutRest.run()"
  >
    <p class="text-sm">Every device except this one will need to sign in again. Access tokens they already have expire within a few minutes.</p>
  </ConfirmDialog>
</template>
