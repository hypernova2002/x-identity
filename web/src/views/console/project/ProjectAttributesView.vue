<script setup lang="ts">
import { ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseCheckbox from '@/components/base/BaseCheckbox.vue'
import BaseDataTable from '@/components/base/BaseDataTable.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import type { DataTableColumn, DataTableFilter } from '@/components/base/types'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useListView } from '@/composables/useListView'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AttributeDataType, AttributeDefinition } from '@/types/api'
import { attributeDataTypeOptions, yesNoOptions } from '@/utils/options'

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
  { key: 'label', label: 'Attribute', sortKey: 'label' },
  { key: 'data_type', label: 'Type', sortKey: 'data_type' },
  { key: 'required', label: 'Required' },
  { key: 'user_editable', label: 'End users can edit' },
  { key: 'include_in_token', label: 'In ID token' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const typeLabels = Object.fromEntries(attributeDataTypeOptions.map((option) => [option.value, option.label]))

const filters: DataTableFilter[] = [
  { type: 'select', key: 'data_type_eq', label: 'Type', options: attributeDataTypeOptions },
  { type: 'select', key: 'required_eq', label: 'Required', options: yesNoOptions },
  { type: 'select', key: 'user_editable_eq', label: 'End users can edit', options: yesNoOptions },
  { type: 'select', key: 'include_in_token_eq', label: 'In ID token', options: yesNoOptions },
]

const list = useListView((params) => projectAdminService.listAttributes(accountUid.value, project.value!.uid, params), {
  defaultSort: 'created_at',
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
  <BaseCard
    title="Attributes"
    description="Extra profile fields for this project's end users. Values are checked on sign-up, profile updates and admin changes."
  >
    <BaseAlert v-if="update.error.value" variant="danger">{{ update.error.value.message }}</BaseAlert>

    <BaseDataTable
      v-model:state="listState"
      caption="Attributes"
      search-label="Search by key or label"
      :columns="columns"
      :filters="filters"
      :rows="list.rows.value"
      :row-key="(definition) => definition.uid"
      :total="list.total.value"
      :per-page="list.perPage.value"
      :loading="list.loading.value"
      :error="list.error.value"
      empty-message="No custom attributes yet. End users have an email and name."
      @retry="list.reload"
    >
      <template v-if="access.admin" #actions>
        <BaseButton label="Add attribute" @click="createOpen = true" />
      </template>
      <template #cell-label="{ row }">
        <span class="font-medium">{{ row.label }}</span>
        <code class="block font-mono text-xs text-text-muted">{{ row.key }}</code>
      </template>
      <template #cell-data_type="{ row }">
        {{ typeLabels[row.data_type] }}<span v-if="row.max_length" class="text-text-muted"> · max {{ row.max_length }}</span>
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
        <BaseButton v-if="access.admin" label="Delete" variant="ghost" size="sm" @click="pendingDelete = row" />
      </template>
    </BaseDataTable>
  </BaseCard>

  <BaseDialog v-model:visible="createOpen" title="Add attribute">
    <form id="create-attribute" class="flex flex-col gap-4" novalidate @submit.prevent="create.run()">
      <BaseAlert v-if="create.error.value && create.error.value.details.length === 0" variant="danger">{{ create.error.value.message }}</BaseAlert>
      <BaseInput v-model="label" label="Label" required hint="Shown in the console, e.g. Loyalty tier." :error="create.error.value?.fieldError('label')" />
      <BaseInput
        v-model="key"
        label="Key"
        required
        hint="Used in the API, e.g. loyalty_tier. Lowercase letters, numbers and underscores. Can't be changed later."
        :error="create.error.value?.fieldError('key')"
      />
      <BaseSelect v-model="dataType" label="Type" :options="attributeDataTypeOptions" hint="Can't be changed later." />
      <BaseInput
        v-if="dataType === 'string'"
        v-model="maxLength"
        label="Maximum length"
        type="number"
        hint="Optional. Up to 2048 characters."
        :error="create.error.value?.fieldError('max_length')"
      />
      <BaseCheckbox v-model="required" label="Required" />
      <BaseCheckbox v-model="userEditable" label="End users can set and edit it" hint="Off for values only your admins or backend should set." />
      <BaseCheckbox v-model="includeInToken" label="Include in ID tokens" hint="Added to the custom_attributes claim." />
    </form>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="createOpen = false" />
      <BaseButton label="Add attribute" type="submit" form="create-attribute" :loading="create.loading.value" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="pendingDelete !== null" title="Delete attribute?" @update:visible="(open: boolean) => !open && (pendingDelete = null)">
    <p class="text-sm">
      This deletes <strong>{{ pendingDelete?.label }}</strong> and removes its value from every end user in the project.
    </p>
    <BaseAlert v-if="destroy.error.value" variant="danger">{{ destroy.error.value.message }}</BaseAlert>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="pendingDelete = null" />
      <BaseButton label="Delete attribute" variant="danger" :loading="destroy.loading.value" @click="pendingDelete && destroy.run(pendingDelete)" />
    </template>
  </BaseDialog>
</template>
