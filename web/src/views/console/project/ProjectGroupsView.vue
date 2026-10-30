<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BasePagination from '@/components/base/BasePagination.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import StatCards from '@/components/console/StatCards.vue'
import RoutePageHeader from '@/components/console/RoutePageHeader.vue'
import { useAsync } from '@/composables/useAsync'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useListView } from '@/composables/useListView'
import { useProjectContext } from '@/composables/useProjectContext'
import type { Page } from '@/services/http'
import { projectAdminService } from '@/services/project'
import type { EndUser, Group } from '@/types/api'
import { yesNoOptions } from '@/utils/options'

const { t } = useI18n()

const route = useRoute()
const { accountUid, project, access } = useProjectContext()

const editing = ref<Group | null>(null)
const formOpen = ref(false)
const name = ref('')
const description = ref('')
const defaultForNewUsers = ref(false)
const pendingDelete = ref<Group | null>(null)

const membersOf = ref<Group | null>(null)
const members = ref<Page<EndUser>>({ items: [], total: 0, perPage: 25 })
const membersPage = ref(1)
const memberEmail = ref('')
const memberMatches = ref<EndUser[]>([])

const columns: DataTableColumn[] = [
  { key: 'name', label: t('project.projectGroups.group'), sortKey: 'name' },
  { key: 'member_count', label: t('project.projectGroups.members'), sortKey: 'member_count' },
  { key: 'default_for_new_users', label: t('project.projectGroups.newUsers') },
  { key: 'actions', label: t('project.projectGroups.actions'), srOnly: true },
]
const filters: DataTableFilter[] = [
  { type: 'select', key: 'default_for_new_users_eq', label: t('project.projectGroups.newUsersJoin'), options: yesNoOptions },
]

const list = useListView((params) => projectAdminService.listGroups(accountUid.value, project.value!.uid, params), {
  defaultSort: 'name',
  storageKey: 'groups',
  filterKeys: filters.map((filter) => filter.key),
  syncRoute: true,
})
const listState = list.state

const stats = useAsync(() => projectAdminService.groupStats(accountUid.value, project.value!.uid))
const statCards = computed(() => [
  { label: t('project.projectGroups.groups'), value: stats.data.value?.total },
  { label: t('project.projectGroups.withoutMembers'), value: stats.data.value?.empty },
])

function reloadAll() {
  return Promise.all([list.reload(), stats.reload()])
}

/** Links from users, applications and providers open a group's members. */
const openLinked = useAsyncAction(async () => {
  if (!project.value || typeof route.query.group !== 'string') return
  openMembers(await projectAdminService.getGroup(accountUid.value, project.value.uid, route.query.group))
})

function openForm(group: Group | null) {
  editing.value = group
  name.value = group?.name ?? ''
  description.value = group?.description ?? ''
  defaultForNewUsers.value = group?.default_for_new_users ?? false
  save.error.value = null
  formOpen.value = true
}

const save = useAsyncAction(async () => {
  if (!project.value) return
  const input = { name: name.value, description: description.value.trim() || null, default_for_new_users: defaultForNewUsers.value }
  if (editing.value) await projectAdminService.updateGroup(accountUid.value, project.value.uid, editing.value.uid, input)
  else await projectAdminService.createGroup(accountUid.value, project.value.uid, input)
  formOpen.value = false
  await reloadAll()
})

const destroy = useAsyncAction(async (group: Group) => {
  if (!project.value) return
  await projectAdminService.deleteGroup(accountUid.value, project.value.uid, group.uid)
  pendingDelete.value = null
  await reloadAll()
})

const loadMembers = useAsyncAction(async () => {
  if (!project.value || !membersOf.value) return
  members.value = await projectAdminService.listGroupMembers(accountUid.value, project.value.uid, membersOf.value.uid, membersPage.value)
})

function openMembers(group: Group) {
  membersOf.value = group
  membersPage.value = 1
  memberEmail.value = ''
  memberMatches.value = []
  loadMembers.run()
}

const searchMembers = useAsyncAction(async () => {
  if (!project.value) return
  memberMatches.value = (await projectAdminService.listEndUsers(accountUid.value, project.value.uid, { search: memberEmail.value })).items
})

const addMember = useAsyncAction(async (endUser: EndUser) => {
  if (!project.value || !membersOf.value) return
  await projectAdminService.addGroupMember(accountUid.value, project.value.uid, membersOf.value.uid, endUser.uid)
  await Promise.all([loadMembers.run(), reloadAll()])
})

const removeMember = useAsyncAction(async (endUser: EndUser) => {
  if (!project.value || !membersOf.value) return
  await projectAdminService.removeGroupMember(accountUid.value, project.value.uid, membersOf.value.uid, endUser.uid)
  await Promise.all([loadMembers.run(), reloadAll()])
})

const isMember = (endUser: EndUser) => members.value.items.some((member) => member.uid === endUser.uid) || endUser.groups.some((group) => group.uid === membersOf.value?.uid)

watch(membersPage, () => loadMembers.run())
onMounted(() => {
  openLinked.run()
  stats.reload()
})
</script>

<template>
  <RoutePageHeader>
    <template v-if="access.developer" #actions>
      <BaseButton :label="$t('project.projectGroups.createGroup')" @click="openForm(null)" />
    </template>
  </RoutePageHeader>

  <StatCards :label="$t('project.projectGroups.groupCounts')" :cards="statCards" :loading="stats.loading.value" :error="stats.error.value" @retry="stats.reload" />

  <BaseCard>
    <BaseAlert v-if="openLinked.error.value" variant="danger">{{ $t('project.projectGroups.openFailed', { message: openLinked.error.value.message }) }}</BaseAlert>
    <BaseAlert v-if="destroy.error.value" variant="danger">{{ destroy.error.value.message }}</BaseAlert>

    <BaseDataTable
      storage-key="groups"
      v-model:state="listState"
      :caption="$t('project.projectGroups.groups')"
      :search-placeholder="$t('project.projectGroups.searchGroups')"
      :search-label="$t('project.projectGroups.searchByName')"
      :columns="columns"
      :filters="filters"
      :rows="list.rows.value"
      :row-key="(group) => group.uid"
      :total="list.total.value"
      :per-page="list.perPage.value"
      :loading="list.loading.value"
      :error="list.error.value"
      :empty-message="$t('project.projectGroups.noGroupsYetCreateOne')"
      @reload="reloadAll"
    >
      <template #cell-name="{ row }">
        <span class="font-medium">{{ row.name }}</span>
        <span v-if="row.description" class="block text-xs text-text-muted">{{ row.description }}</span>
      </template>
      <template #cell-default_for_new_users="{ row }">{{ row.default_for_new_users ? $t('project.projectGroups.joinAutomatically') : '—' }}</template>
      <template #cell-actions="{ row }">
        <div class="flex flex-wrap justify-end gap-2">
          <BaseButton :label="$t('project.projectGroups.members')" variant="secondary" size="sm" @click="openMembers(row)" />
          <template v-if="access.developer">
            <BaseButton :label="$t('project.projectGroups.edit')" variant="secondary" size="sm" @click="openForm(row)" />
            <BaseButton :label="$t('project.projectGroups.delete')" variant="ghost" size="sm" @click="pendingDelete = row" />
          </template>
        </div>
      </template>
    </BaseDataTable>
  </BaseCard>

  <BaseDialog v-model:visible="formOpen" :title="editing ? $t('project.projectGroups.edit2', { name: editing.name }) : $t('project.projectGroups.createGroup')">
    <form id="group-form" class="flex flex-col gap-4" novalidate @submit.prevent="save.run()">
      <BaseAlert v-if="save.error.value && save.error.value.details.length === 0" variant="danger">{{ save.error.value.message }}</BaseAlert>
      <BaseInput v-model="name" :label="$t('project.projectGroups.name')" required :error="save.error.value?.fieldError('name')" />
      <BaseInput v-model="description" :label="$t('project.projectGroups.description')" :error="save.error.value?.fieldError('description')" />
      <BaseCheckbox
        v-model="defaultForNewUsers"
        :label="$t('project.projectGroups.newEndUsersJoinAutomatically')"
        :hint="$t('project.projectGroups.everyoneWhoSignsUpOr')"
      />
    </form>
    <template #footer>
      <BaseButton :label="$t('project.projectGroups.cancel')" variant="secondary" @click="formOpen = false" />
      <BaseButton :label="editing ? $t('project.projectGroups.save') : $t('project.projectGroups.create')" type="submit" form="group-form" :loading="save.loading.value" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="membersOf !== null" :title="$t('project.projectGroups.membersOf2', { name: membersOf?.name ?? '' })" @update:visible="(open: boolean) => !open && (membersOf = null)">
    <BaseAlert v-if="loadMembers.error.value" variant="danger">{{ loadMembers.error.value.message }}</BaseAlert>
    <BaseAlert v-if="addMember.error.value" variant="danger">{{ addMember.error.value.message }}</BaseAlert>
    <BaseAlert v-if="removeMember.error.value" variant="danger">{{ removeMember.error.value.message }}</BaseAlert>

    <p v-if="!loadMembers.loading.value && members.items.length === 0" class="text-sm text-text-muted">{{ $t('project.projectGroups.noMembersYet') }}</p>
    <ul v-else class="flex flex-col divide-y divide-border">
      <li v-for="member in members.items" :key="member.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
        <span>
          <RouterLink :to="{ name: 'project-end-user', params: { projectUid: project?.uid, endUserUid: member.uid } }" class="font-medium text-primary underline-offset-2 hover:underline">
            {{ member.email }}
          </RouterLink>
          <span v-if="member.name" class="ml-2 text-text-muted">{{ member.name }}</span>
        </span>
        <BaseButton v-if="access.developer" :label="$t('project.projectGroups.remove')" variant="ghost" size="sm" :loading="removeMember.loading.value" @click="removeMember.run(member)" />
      </li>
    </ul>
    <BasePagination v-model:page="membersPage" class="self-end" :label="$t('project.projectGroups.membersPagination')" :total="members.total" :per-page="members.perPage" :row-count="members.items.length" :disabled="loadMembers.loading.value" />

    <template v-if="access.developer">
      <form class="flex flex-wrap items-end gap-2 border-t border-border pt-4" novalidate @submit.prevent="searchMembers.run()">
        <div class="min-w-48 flex-1">
          <BaseInput v-model="memberEmail" :label="$t('project.projectGroups.addAnEndUser')" type="search" :hint="$t('project.projectGroups.searchByEmail')" />
        </div>
        <BaseButton type="submit" :label="$t('project.projectGroups.search')" variant="secondary" :loading="searchMembers.loading.value" />
      </form>
      <ul v-if="memberMatches.length > 0" class="flex flex-col divide-y divide-border">
        <li v-for="endUser in memberMatches" :key="endUser.uid" class="flex items-center justify-between gap-2 py-2 text-sm">
          <span>{{ endUser.email }}</span>
          <span v-if="isMember(endUser)" class="text-xs text-text-muted">{{ $t('project.projectGroups.member') }}</span>
          <BaseButton v-else :label="$t('project.projectGroups.add')" variant="secondary" size="sm" :loading="addMember.loading.value" @click="addMember.run(endUser)" />
        </li>
      </ul>
    </template>

    <template #footer>
      <BaseButton :label="$t('project.projectGroups.done')" @click="membersOf = null" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="pendingDelete !== null" :title="$t('project.projectGroups.deleteGroup')" @update:visible="(open: boolean) => !open && (pendingDelete = null)">
    <i18n-t keypath="project.projectGroups.deleteDescription" tag="p" class="text-sm">
      <template #name><strong>{{ pendingDelete?.name }}</strong></template>
    </i18n-t>
    <template #footer>
      <BaseButton :label="$t('project.projectGroups.cancel')" variant="secondary" @click="pendingDelete = null" />
      <BaseButton :label="$t('project.projectGroups.deleteGroup2')" variant="danger" :loading="destroy.loading.value" @click="pendingDelete && destroy.run(pendingDelete)" />
    </template>
  </BaseDialog>
</template>
