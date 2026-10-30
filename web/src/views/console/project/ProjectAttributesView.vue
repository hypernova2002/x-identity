<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import RoutePageHeader from '@/components/console/RoutePageHeader.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useListView } from '@/composables/useListView'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AttributeDataType, AttributeDefinition } from '@/types/api'
import { attributeDataTypeOptions, yesNoOptions } from '@/utils/options'

const { t } = useI18n()

type Flag = 'required' | 'user_editable' | 'include_in_token'

const { accountUid, project, access } = useProjectContext()

const createOpen = ref(false)
const key = ref('')
const label = ref('')
const dataType = ref<AttributeDataType>('string')
const maxLength = ref('')
const required = ref(false)
const userEditable = ref(true)
const includeInToken = ref(false)
const pendingDelete = ref<AttributeDefinition | null>(null)

const columns: DataTableColumn[] = [
  { key: 'label', label: t('project.projectAttributes.attribute'), sortKey: 'label' },
  { key: 'data_type', label: t('project.projectAttributes.type'), sortKey: 'data_type' },
  { key: 'required', label: t('project.projectAttributes.required') },
  { key: 'user_editable', label: t('project.projectAttributes.endUsersCanEdit') },
  { key: 'include_in_token', label: t('project.projectAttributes.inIdToken') },
  { key: 'actions', label: t('project.projectAttributes.actions'), srOnly: true },
]

const typeLabels = Object.fromEntries(attributeDataTypeOptions.map((option) => [option.value, option.label]))

const filters: DataTableFilter[] = [
  { type: 'select', key: 'data_type_eq', label: t('project.projectAttributes.type'), options: attributeDataTypeOptions },
  { type: 'select', key: 'required_eq', label: t('project.projectAttributes.required'), options: yesNoOptions },
  { type: 'select', key: 'user_editable_eq', label: t('project.projectAttributes.endUsersCanEdit'), options: yesNoOptions },
  { type: 'select', key: 'include_in_token_eq', label: t('project.projectAttributes.inIdToken'), options: yesNoOptions },
]

const list = useListView((params) => projectAdminService.listAttributes(accountUid.value, project.value!.uid, params), {
  defaultSort: 'created_at',
  storageKey: 'attributes',
  filterKeys: filters.map((filter) => filter.key),
  syncRoute: true,
})
const listState = list.state

const create = useAsyncAction(async () => {
  if (!project.value) return
  await projectAdminService.createAttribute(accountUid.value, project.value.uid, {
    key: key.value.trim(),
    label: label.value,
    data_type: dataType.value,
    required: required.value,
    max_length: dataType.value === 'string' && maxLength.value.trim() !== '' ? Number(maxLength.value) : null,
    user_editable: userEditable.value,
    include_in_token: includeInToken.value,
  })
  createOpen.value = false
  key.value = ''
  label.value = ''
  maxLength.value = ''
  await list.reload()
})

const update = useAsyncAction(async (definition: AttributeDefinition, flag: Flag, value: boolean) => {
  if (!project.value) return
  await projectAdminService.updateAttribute(accountUid.value, project.value.uid, definition.uid, { [flag]: value })
  await list.reload()
})

const destroy = useAsyncAction(async (definition: AttributeDefinition) => {
  if (!project.value) return
  await projectAdminService.deleteAttribute(accountUid.value, project.value.uid, definition.uid)
  pendingDelete.value = null
  await list.reload()
})

</script>

<template>
  <RoutePageHeader>
    <template v-if="access.admin" #actions>
      <BaseButton :label="$t('project.projectAttributes.addAttribute')" @click="createOpen = true" />
    </template>
  </RoutePageHeader>

  <BaseCard>
    <BaseAlert v-if="update.error.value" variant="danger">{{ update.error.value.message }}</BaseAlert>

    <BaseDataTable
      storage-key="attributes"
      v-model:state="listState"
      :caption="$t('project.projectAttributes.attributes')"
      :search-placeholder="$t('project.projectAttributes.searchAttributes')"
      :search-label="$t('project.projectAttributes.searchByKeyOrLabel')"
      :columns="columns"
      :filters="filters"
      :rows="list.rows.value"
      :row-key="(definition) => definition.uid"
      :total="list.total.value"
      :per-page="list.perPage.value"
      :loading="list.loading.value"
      :error="list.error.value"
      :empty-message="$t('project.projectAttributes.noCustomAttributesYetEnd')"
      @reload="list.reload"
    >
      <template #cell-label="{ row }">
        <span class="font-medium">{{ row.label }}</span>
        <code class="block font-mono text-xs text-text-muted">{{ row.key }}</code>
      </template>
      <template #cell-data_type="{ row }">
        {{ typeLabels[row.data_type] }}<span v-if="row.max_length" class="text-text-muted">{{ $t('project.projectAttributes.maxLength', { count: row.max_length }) }}</span>
      </template>
      <template v-for="flag in (['required', 'user_editable', 'include_in_token'] as const)" :key="flag" #[`cell-${flag}`]="{ row }">
        <BaseCheckbox
          :model-value="row[flag]"
          :label="`${columns.find((column) => column.key === flag)?.label} for ${row.label}`"
          class="[&_label]:sr-only"
          :disabled="!access.admin || update.loading.value"
          @update:model-value="(value: boolean) => update.run(row, flag, value)"
        />
      </template>
      <template #cell-actions="{ row }">
        <BaseButton v-if="access.admin" :label="$t('project.projectAttributes.delete')" variant="ghost" size="sm" @click="pendingDelete = row" />
      </template>
    </BaseDataTable>
  </BaseCard>

  <BaseDialog v-model:visible="createOpen" :title="$t('project.projectAttributes.addAttribute')">
    <form id="create-attribute" class="flex flex-col gap-4" novalidate @submit.prevent="create.run()">
      <BaseAlert v-if="create.error.value && create.error.value.details.length === 0" variant="danger">{{ create.error.value.message }}</BaseAlert>
      <BaseInput v-model="label" :label="$t('project.projectAttributes.label')" required :hint="$t('project.projectAttributes.shownInTheConsoleE')" :error="create.error.value?.fieldError('label')" />
      <BaseInput
        v-model="key"
        :label="$t('project.projectAttributes.key')"
        required
        :hint="$t('project.projectAttributes.usedInTheApiE')"
        :error="create.error.value?.fieldError('key')"
      />
      <BaseSelect v-model="dataType" :label="$t('project.projectAttributes.type')" :options="attributeDataTypeOptions" :hint="$t('project.projectAttributes.canTBeChangedLater')" />
      <BaseInput
        v-if="dataType === 'string'"
        v-model="maxLength"
        :label="$t('project.projectAttributes.maximumLength')"
        type="number"
        :hint="$t('project.projectAttributes.optionalUpToCharacters')"
        :error="create.error.value?.fieldError('max_length')"
      />
      <BaseCheckbox v-model="required" :label="$t('project.projectAttributes.required')" />
      <BaseCheckbox v-model="userEditable" :label="$t('project.projectAttributes.endUsersCanSetAnd')" :hint="$t('project.projectAttributes.offForValuesOnlyYour')" />
      <BaseCheckbox v-model="includeInToken" :label="$t('project.projectAttributes.includeInIdTokens')" :hint="$t('project.projectAttributes.addedToTheCustomAttributes')" />
    </form>
    <template #footer>
      <BaseButton :label="$t('project.projectAttributes.cancel')" variant="secondary" @click="createOpen = false" />
      <BaseButton :label="$t('project.projectAttributes.addAttribute')" type="submit" form="create-attribute" :loading="create.loading.value" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="pendingDelete !== null" :title="$t('project.projectAttributes.deleteAttribute')" @update:visible="(open: boolean) => !open && (pendingDelete = null)">
    <i18n-t keypath="project.projectAttributes.deleteDescription" tag="p" class="text-sm">
      <template #label><strong>{{ pendingDelete?.label }}</strong></template>
    </i18n-t>
    <BaseAlert v-if="destroy.error.value" variant="danger">{{ destroy.error.value.message }}</BaseAlert>
    <template #footer>
      <BaseButton :label="$t('project.projectAttributes.cancel')" variant="secondary" @click="pendingDelete = null" />
      <BaseButton :label="$t('project.projectAttributes.deleteAttribute2')" variant="danger" :loading="destroy.loading.value" @click="pendingDelete && destroy.run(pendingDelete)" />
    </template>
  </BaseDialog>
</template>
