<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { SelectOption } from '@/components/base/types'
import { useAppAccess, type AppRef } from '@/composables/useAppAccess'

const props = defineProps<{
  accountUid: string
  projectUid: string
  /** The app whose access is shown; null closes the dialog. */
  app: AppRef | null
  canManage: boolean
}>()

const emit = defineEmits<{
  close: []
}>()

const access = useAppAccess()
const { assignments, unassignedGroups, endUserMatches } = access

const groupUid = ref('')
const email = ref('')

const groupOptions = computed<SelectOption[]>(() => unassignedGroups.value.map((group) => ({ label: `${group.name} (${group.member_count})`, value: group.uid })))
const error = computed(() => access.load.error.value ?? access.assign.error.value ?? access.unassign.error.value ?? access.searchEndUsers.error.value)

watch(unassignedGroups, (available) => {
  if (!available.some((group) => group.uid === groupUid.value)) groupUid.value = available[0]?.uid ?? ''
})

watch(
  () => props.app,
  (app) => {
    email.value = ''
    if (app) access.load.run(props.accountUid, props.projectUid, app)
  },
  { immediate: true },
)
</script>

<template>
  <BaseDialog :visible="app !== null" :title="`Who can use ${app?.name ?? ''}`" @update:visible="(open: boolean) => !open && emit('close')">
    <p class="text-sm text-text-muted">Only assigned end users, directly or through a group, can sign in to this app.</p>
    <BaseAlert v-if="error" variant="danger">{{ error.message }}</BaseAlert>
    <p v-if="access.load.loading.value" class="text-sm text-text-muted" role="status">Loading…</p>

    <template v-else>
      <p v-if="assignments.length === 0" class="text-sm">Nobody is assigned yet, so nobody can sign in to this app.</p>
      <ul v-else class="flex flex-col divide-y divide-border">
        <li v-for="assignment in assignments" :key="assignment.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
          <span>
            <span class="font-medium">{{ assignment.principal_label }}</span>
            <span class="ml-2 text-xs text-text-muted">{{ assignment.principal_type === 'group' ? 'Group' : 'End user' }}</span>
          </span>
          <BaseButton v-if="canManage" label="Remove" variant="ghost" size="sm" :loading="access.unassign.loading.value" @click="access.unassign.run(assignment)" />
        </li>
      </ul>

      <template v-if="canManage">
        <div class="flex flex-wrap items-end gap-2 border-t border-border pt-4">
          <div class="min-w-48 flex-1">
            <BaseSelect v-if="groupOptions.length > 0" v-model="groupUid" label="Add a group" :options="groupOptions" />
            <p v-else class="text-sm text-text-muted">Every group is already assigned.</p>
          </div>
          <BaseButton
            v-if="groupOptions.length > 0"
            label="Add group"
            variant="secondary"
            :loading="access.assign.loading.value"
            @click="access.assign.run('group', groupUid)"
          />
        </div>

        <form class="flex flex-wrap items-end gap-2" novalidate @submit.prevent="access.searchEndUsers.run(email)">
          <div class="min-w-48 flex-1">
            <BaseInput v-model="email" label="Add an end user" type="search" hint="Search by email." />
          </div>
          <BaseButton type="submit" label="Search" variant="secondary" :loading="access.searchEndUsers.loading.value" />
        </form>
        <ul v-if="endUserMatches.length > 0" class="flex flex-col divide-y divide-border">
          <li v-for="endUser in endUserMatches" :key="endUser.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
            <span>{{ endUser.email }}</span>
            <span v-if="access.isAssigned('end_user', endUser.uid)" class="text-xs text-text-muted">Assigned</span>
            <BaseButton v-else label="Add" variant="secondary" size="sm" :loading="access.assign.loading.value" @click="access.assign.run('end_user', endUser.uid)" />
          </li>
        </ul>
      </template>
    </template>

    <template #footer>
      <BaseButton label="Done" @click="emit('close')" />
    </template>
  </BaseDialog>
</template>
