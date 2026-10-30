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
    :title="$t('project.appAccess.whoCanSignIn')"
    :description="$t('project.appAccess.accessIsAssignmentOnlyOnly')"
  >
    <BaseAlert v-if="error" variant="danger">{{ error.message }}</BaseAlert>
    <p v-if="access.load.loading.value" class="text-sm text-text-muted" role="status">{{ $t('project.appAccess.loadingAccess') }}</p>

    <template v-else>
      <BaseAlert v-if="assignments.length === 0" variant="warning" :title="$t('project.appAccess.nobodyCanSignInYet')">
        {{ $t('project.appAccess.assignAGroupOrEnd') }}
      </BaseAlert>

      <section v-if="groupAssignments.length > 0" class="flex flex-col gap-1" aria-labelledby="access-groups-heading">
        <h3 id="access-groups-heading" class="text-sm font-semibold">{{ $t('project.appAccess.groups') }}</h3>
        <ul class="flex flex-col divide-y divide-border">
          <li v-for="assignment in groupAssignments" :key="assignment.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
            <span class="flex items-center gap-2">
              <RouterLink
                :to="{ name: 'project-groups', params: { projectUid }, query: { group: assignment.principal_uid } }"
                class="font-medium text-primary underline-offset-2 hover:underline"
              >
                {{ assignment.principal_label }}
              </RouterLink>
              <StatusBadge tone="info" :label="$t('project.appAccess.everyMember')" />
            </span>
            <BaseButton v-if="canManage" :label="$t('project.appAccess.remove')" variant="ghost" size="sm" :loading="access.unassign.loading.value" @click="access.unassign.run(assignment)" />
          </li>
        </ul>
      </section>

      <section v-if="directAssignments.length > 0" class="flex flex-col gap-1" aria-labelledby="access-users-heading">
        <h3 id="access-users-heading" class="text-sm font-semibold">{{ $t('project.appAccess.endUsersAssignedDirectly') }}</h3>
        <ul class="flex flex-col divide-y divide-border">
          <li v-for="assignment in directAssignments" :key="assignment.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
            <RouterLink
              :to="{ name: 'project-end-user', params: { projectUid, endUserUid: assignment.principal_uid } }"
              class="font-medium text-primary underline-offset-2 hover:underline"
            >
              {{ assignment.principal_label }}
            </RouterLink>
            <BaseButton v-if="canManage" :label="$t('project.appAccess.remove')" variant="ghost" size="sm" :loading="access.unassign.loading.value" @click="access.unassign.run(assignment)" />
          </li>
        </ul>
      </section>

      <template v-if="canManage">
        <div class="flex flex-wrap items-end gap-2 border-t border-border pt-4">
          <div class="min-w-48 flex-1">
            <BaseSearchSelect
              v-model="groupUid"
              :label="$t('project.appAccess.assignAGroup')"
              :search="access.searchUnassignedGroups"
              :see-all="{ name: 'project-groups', params: { projectUid } }"
            />
          </div>
          <BaseButton :label="$t('project.appAccess.assignGroup')" variant="secondary" :disabled="!groupUid" :loading="access.assign.loading.value" @click="assignGroup" />
        </div>

        <form class="flex flex-wrap items-end gap-2" novalidate @submit.prevent="access.searchEndUsers.run(email)">
          <div class="min-w-48 flex-1">
            <BaseInput v-model="email" :label="$t('project.appAccess.assignAnEndUser')" type="search" :hint="$t('project.appAccess.searchByEmail')" />
          </div>
          <BaseButton type="submit" :label="$t('project.appAccess.search')" variant="secondary" :loading="access.searchEndUsers.loading.value" />
        </form>
        <ul v-if="endUserMatches.length > 0" class="flex flex-col divide-y divide-border">
          <li v-for="endUser in endUserMatches" :key="endUser.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
            <span>{{ endUser.email }}</span>
            <StatusBadge v-if="access.isAssigned('end_user', endUser.uid)" tone="success" :label="$t('project.appAccess.assigned')" />
            <BaseButton v-else :label="$t('project.appAccess.assign')" variant="secondary" size="sm" :loading="access.assign.loading.value" @click="access.assign.run('end_user', endUser.uid)" />
          </li>
        </ul>
      </template>
      <BaseAlert v-else variant="info">{{ $t('project.appAccess.onlyProjectAdminsAndDevelopers') }}</BaseAlert>
    </template>
  </BaseCard>
</template>
