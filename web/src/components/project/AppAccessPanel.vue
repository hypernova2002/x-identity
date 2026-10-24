<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSearchSelect from '@/components/base/BaseSearchSelect.vue'
import StatusBadge from '@/components/console/StatusBadge.vue'
import { useAppAccess, type AppRef } from '@/composables/useAppAccess'

const props = defineProps<{
  accountUid: string
  projectUid: string
  app: AppRef
  canManage: boolean
}>()

const access = useAppAccess()
const { assignments, endUserMatches } = access

const groupUid = ref('')
const email = ref('')

const error = computed(() => access.load.error.value ?? access.assign.error.value ?? access.unassign.error.value ?? access.searchEndUsers.error.value)
const groupAssignments = computed(() => assignments.value.filter((assignment) => assignment.principal_type === 'group'))
const directAssignments = computed(() => assignments.value.filter((assignment) => assignment.principal_type === 'end_user'))

async function assignGroup() {
  await access.assign.run('group', groupUid.value)
  if (!access.assign.error.value) groupUid.value = ''
}

watch(
  () => props.app.uid,
  () => {
    email.value = ''
    access.load.run(props.accountUid, props.projectUid, props.app)
  },
  { immediate: true },
)
</script>

<template>
  <BaseCard
    title="Who can sign in"
    description="Access is assignment-only: only end users assigned directly, or through one of their groups, can sign in. x-identity checks this on every sign-in, token refresh and single sign-on."
  >
    <BaseAlert v-if="error" variant="danger">{{ error.message }}</BaseAlert>
    <p v-if="access.load.loading.value" class="text-sm text-text-muted" role="status">Loading access…</p>

    <template v-else>
      <BaseAlert v-if="assignments.length === 0" variant="warning" title="Nobody can sign in yet">
        Assign a group or end users below.
      </BaseAlert>

      <section v-if="groupAssignments.length > 0" class="flex flex-col gap-1" aria-labelledby="access-groups-heading">
        <h3 id="access-groups-heading" class="text-sm font-semibold">Groups</h3>
        <ul class="flex flex-col divide-y divide-border">
          <li v-for="assignment in groupAssignments" :key="assignment.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
            <span class="flex items-center gap-2">
              <RouterLink
                :to="{ name: 'project-groups', params: { projectUid }, query: { group: assignment.principal_uid } }"
                class="font-medium text-primary underline-offset-2 hover:underline"
              >
                {{ assignment.principal_label }}
              </RouterLink>
              <StatusBadge tone="info" label="Every member" />
            </span>
            <BaseButton v-if="canManage" label="Remove" variant="ghost" size="sm" :loading="access.unassign.loading.value" @click="access.unassign.run(assignment)" />
          </li>
        </ul>
      </section>

      <section v-if="directAssignments.length > 0" class="flex flex-col gap-1" aria-labelledby="access-users-heading">
        <h3 id="access-users-heading" class="text-sm font-semibold">End users assigned directly</h3>
        <ul class="flex flex-col divide-y divide-border">
          <li v-for="assignment in directAssignments" :key="assignment.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
            <RouterLink
              :to="{ name: 'project-end-user', params: { projectUid, endUserUid: assignment.principal_uid } }"
              class="font-medium text-primary underline-offset-2 hover:underline"
            >
              {{ assignment.principal_label }}
            </RouterLink>
            <BaseButton v-if="canManage" label="Remove" variant="ghost" size="sm" :loading="access.unassign.loading.value" @click="access.unassign.run(assignment)" />
          </li>
        </ul>
      </section>

      <template v-if="canManage">
        <div class="flex flex-wrap items-end gap-2 border-t border-border pt-4">
          <div class="min-w-48 flex-1">
            <BaseSearchSelect
              v-model="groupUid"
              label="Assign a group"
              :search="access.searchUnassignedGroups"
              :see-all="{ name: 'project-groups', params: { projectUid } }"
            />
          </div>
          <BaseButton label="Assign group" variant="secondary" :disabled="!groupUid" :loading="access.assign.loading.value" @click="assignGroup" />
        </div>

        <form class="flex flex-wrap items-end gap-2" novalidate @submit.prevent="access.searchEndUsers.run(email)">
          <div class="min-w-48 flex-1">
            <BaseInput v-model="email" label="Assign an end user" type="search" hint="Search by email." />
          </div>
          <BaseButton type="submit" label="Search" variant="secondary" :loading="access.searchEndUsers.loading.value" />
        </form>
        <ul v-if="endUserMatches.length > 0" class="flex flex-col divide-y divide-border">
          <li v-for="endUser in endUserMatches" :key="endUser.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
            <span>{{ endUser.email }}</span>
            <StatusBadge v-if="access.isAssigned('end_user', endUser.uid)" tone="success" label="Assigned" />
            <BaseButton v-else label="Assign" variant="secondary" size="sm" :loading="access.assign.loading.value" @click="access.assign.run('end_user', endUser.uid)" />
          </li>
        </ul>
      </template>
      <BaseAlert v-else variant="info">Only project admins and developers can change access.</BaseAlert>
    </template>
  </BaseCard>
</template>
