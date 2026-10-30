<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'

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
    /** Whose devices these are, for messages, e.g. "casey@shop.test"; the signed-in user's own when unset. */
    owner?: string
  }>(),
  { signOut: undefined, signOutOthers: undefined, owner: undefined },
)

const { t } = useI18n()

const columns = computed<DataTableColumn[]>(() => [
  { key: 'device', label: t('security.devices.columns.device') },
  { key: 'location', label: t('security.devices.columns.location') },
  { key: 'created_at', label: t('security.devices.columns.signedIn'), sortKey: 'created_at', sortKind: 'date' },
  { key: 'last_seen_at', label: t('security.devices.columns.lastActive'), sortKey: 'last_seen_at', sortKind: 'date' },
  { key: 'actions', label: t('security.devices.columns.actions'), srOnly: true },
])

const list = useListView(props.fetchPage, { defaultSort: '-last_seen_at', storageKey: 'device-sessions' })
const listState = list.state

const pending = ref<DeviceSession | null>(null)
const othersPending = ref(false)
const notice = ref<string | null>(null)

const signOutOne = useAsyncAction(async (session: DeviceSession) => {
  await props.signOut?.(session)
  pending.value = null
  notice.value = t('security.devices.signedOut', { device: deviceLabel(session) })
  await list.reload()
})

const signOutRest = useAsyncAction(async () => {
  await props.signOutOthers?.()
  othersPending.value = false
  notice.value = t('security.devices.othersSignedOut')
  await list.reload()
})

defineExpose({ reload: list.reload })
</script>

<template>
  <BaseAlert v-if="notice" variant="success">{{ notice }}</BaseAlert>

  <BaseDataTable
    storage-key="device-sessions"
    v-model:state="listState"
    :caption="t('security.devices.caption')"
    :search-placeholder="t('security.devices.searchPlaceholder')"
    :search-label="t('security.devices.searchLabel')"
    :columns="columns"
    :rows="list.rows.value"
    :row-key="(session) => session.uid"
    :total="list.total.value"
    :per-page="list.perPage.value"
    :loading="list.loading.value"
    :error="list.error.value"
    :empty-message="owner ? t('security.devices.emptyOther', { owner }) : t('security.devices.emptyYou')"
    stacked
    @reload="list.reload"
  >
    <template v-if="signOutOthers" #actions>
      <BaseButton :label="t('security.devices.signOutOthers')" variant="secondary" @click="othersPending = true" />
    </template>
    <template #cell-device="{ row }">
      <span class="flex flex-wrap items-center gap-2">
        <span class="font-medium">{{ deviceLabel(row) }}</span>
        <StatusBadge v-if="row.current" tone="info" :label="t('security.devices.thisDevice')" />
      </span>
      <span class="block text-xs text-text-muted">{{ signInMethods(row.amr) }}</span>
    </template>
    <template #cell-location="{ row }">
      <span>{{ formatLocation(row.location) ?? t('security.devices.unknown') }}</span>
      <code v-if="row.ip" class="block font-mono text-xs text-text-muted">{{ row.ip }}</code>
    </template>
    <template #cell-created_at="{ row }"><span class="text-xs">{{ formatDateTime(row.created_at) }}</span></template>
    <template #cell-last_seen_at="{ row }"><span class="text-xs">{{ formatDateTime(row.last_seen_at) }}</span></template>
    <template #cell-actions="{ row }">
      <div class="flex sm:justify-end">
        <BaseButton
          v-if="signOut && !row.current"
          class="whitespace-nowrap"
          :label="t('security.devices.signOut')"
          variant="ghost"
          size="sm"
          :aria-label="t('security.devices.signOutLabel', { device: deviceLabel(row) })"
          @click="pending = row"
        />
      </div>
    </template>
  </BaseDataTable>

  <i18n-t keypath="security.devices.locationNote" tag="p" class="text-xs text-text-muted">
    <template #link>
      <a href="https://db-ip.com" target="_blank" rel="noopener" class="underline">{{ t('security.devices.locationLink') }}</a>
    </template>
  </i18n-t>

  <ConfirmDialog
    :visible="pending !== null"
    :title="t('security.devices.signOutTitle')"
    :confirm-label="t('security.devices.signOutConfirm')"
    danger
    :loading="signOutOne.loading.value"
    :error="signOutOne.error.value"
    @update:visible="(open: boolean) => !open && (pending = null)"
    @confirm="pending && signOutOne.run(pending)"
  >
    <i18n-t keypath="security.devices.signOutDescription" tag="p" class="text-sm">
      <template #device><strong>{{ pending ? deviceLabel(pending) : '' }}</strong></template>
    </i18n-t>
  </ConfirmDialog>

  <ConfirmDialog
    v-model:visible="othersPending"
    :title="t('security.devices.signOutOthersTitle')"
    :confirm-label="t('security.devices.signOutOthersConfirm')"
    danger
    :loading="signOutRest.loading.value"
    :error="signOutRest.error.value"
    @confirm="signOutRest.run()"
  >
    <p class="text-sm">{{ t('security.devices.signOutOthersDescription') }}</p>
  </ConfirmDialog>
</template>
