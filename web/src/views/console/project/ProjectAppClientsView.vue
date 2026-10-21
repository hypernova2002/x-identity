<script setup lang="ts">
import { onMounted, ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import BaseSelect from '@/components/base/BaseSelect.vue'
import BaseTable from '@/components/base/BaseTable.vue'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AppClient, AppClientType, AppClientWithSecret } from '@/types/api'
import { formatDateTime, parseList } from '@/utils/format'
import { appClientTypeOptions } from '@/utils/options'

const { accountUid, project, access } = useProjectContext()

const clients = ref<AppClient[]>([])
const createOpen = ref(false)
const name = ref('')
const clientType = ref<AppClientType>('public')
const origins = ref('')
const redirectUris = ref('')
const postLogoutUris = ref('')
const editing = ref<AppClient | null>(null)
const editName = ref('')
const editOrigins = ref('')
const editRedirectUris = ref('')
const editPostLogoutUris = ref('')
const revealed = ref<AppClientWithSecret | null>(null)
const pendingDelete = ref<AppClient | null>(null)

const redirectUrisHint =
  'Where users return after signing in through hosted login or a sign-in provider, matched exactly. https URLs, ' +
  'http://localhost URLs, or app schemes like com.example.shop:/callback. Separate several with commas.'
const postLogoutUrisHint = 'Where your app may send users after logging out of hosted login, matched exactly. Separate several with commas.'

const columns = [
  { key: 'name', label: 'Name' },
  { key: 'client_type', label: 'Type' },
  { key: 'allowed_origins', label: 'Allowed origins' },
  { key: 'redirect_uris', label: 'Redirect URIs' },
  { key: 'enabled', label: 'Status' },
  { key: 'actions', label: 'Actions', srOnly: true },
]

const load = useAsyncAction(async () => {
  if (!project.value) return
  clients.value = (await projectAdminService.listAppClients(accountUid.value, project.value.uid)).items
})

const create = useAsyncAction(async () => {
  if (!project.value) return
  const created = await projectAdminService.createAppClient(accountUid.value, project.value.uid, {
    name: name.value,
    client_type: clientType.value,
    allowed_origins: parseList(origins.value),
    redirect_uris: parseList(redirectUris.value),
    post_logout_redirect_uris: parseList(postLogoutUris.value),
  })
  clients.value = [...clients.value, created]
  createOpen.value = false
  name.value = ''
  origins.value = ''
  redirectUris.value = ''
  postLogoutUris.value = ''
  revealed.value = created
})

function startEditing(client: AppClient) {
  editing.value = client
  editName.value = client.name
  editOrigins.value = client.allowed_origins.join(', ')
  editRedirectUris.value = client.redirect_uris.join(', ')
  editPostLogoutUris.value = client.post_logout_redirect_uris.join(', ')
  update.error.value = null
}

const update = useAsyncAction(async () => {
  if (!project.value || !editing.value) return
  const updated = await projectAdminService.updateAppClient(accountUid.value, project.value.uid, editing.value.uid, {
    name: editName.value,
    allowed_origins: parseList(editOrigins.value),
    redirect_uris: parseList(editRedirectUris.value),
    post_logout_redirect_uris: parseList(editPostLogoutUris.value),
  })
  clients.value = clients.value.map((existing) => (existing.uid === updated.uid ? updated : existing))
  editing.value = null
})

const clientAction = useAsyncAction(async (client: AppClient, action: 'toggle' | 'rotate' | 'delete') => {
  if (!project.value) return
  if (action === 'delete') {
    await projectAdminService.deleteAppClient(accountUid.value, project.value.uid, client.uid)
    clients.value = clients.value.filter((existing) => existing.uid !== client.uid)
    pendingDelete.value = null
    return
  }

  const updated =
    action === 'rotate'
      ? await projectAdminService.rotateAppClientSecret(accountUid.value, project.value.uid, client.uid)
      : await projectAdminService.updateAppClient(accountUid.value, project.value.uid, client.uid, { enabled: !client.enabled })
  clients.value = clients.value.map((existing) => (existing.uid === updated.uid ? updated : existing))
  if (action === 'rotate') revealed.value = updated as AppClientWithSecret
})

onMounted(() => load.run())
</script>

<template>
  <BaseCard
    title="App clients"
    description="Each app that signs end users in (a website, mobile app or backend) gets a client. Apps send its client ID with every sign-in request."
  >
    <template v-if="access.developer" #footer>
      <BaseButton label="Create app client" @click="createOpen = true" />
    </template>

    <BaseAlert v-if="load.error.value" variant="danger">We couldn't load app clients. {{ load.error.value.message }}</BaseAlert>
    <BaseAlert v-if="clientAction.error.value" variant="danger">{{ clientAction.error.value.message }}</BaseAlert>

    <BaseTable
      caption="App clients"
      :columns="columns"
      :rows="clients"
      :row-key="(client) => client.uid"
      :loading="load.loading.value"
      empty-message="No app clients yet. Create one for each app that signs end users in."
    >
      <template #cell-name="{ row }">
        <span class="font-medium">{{ row.name }}</span>
        <code class="block font-mono text-xs text-text-muted">{{ row.uid }}</code>
      </template>
      <template #cell-client_type="{ row }"><span class="capitalize">{{ row.client_type }}</span></template>
      <template #cell-allowed_origins="{ row }">
        <span v-if="row.allowed_origins.length === 0" class="text-text-muted">None</span>
        <ul v-else class="font-mono text-xs">
          <li v-for="origin in row.allowed_origins" :key="origin">{{ origin }}</li>
        </ul>
      </template>
      <template #cell-redirect_uris="{ row }">
        <span v-if="row.redirect_uris.length === 0" class="text-text-muted">None</span>
        <ul v-else class="font-mono text-xs break-all">
          <li v-for="uri in row.redirect_uris" :key="uri">{{ uri }}</li>
        </ul>
      </template>
      <template #cell-enabled="{ row }">
        <span :class="row.enabled ? 'text-success' : 'text-text-muted'" class="font-medium">
          {{ row.enabled ? '● Enabled' : '○ Disabled' }}
        </span>
        <span class="block text-xs text-text-muted">Since {{ formatDateTime(row.created_at) }}</span>
      </template>
      <template #cell-actions="{ row }">
        <div v-if="access.developer" class="flex flex-wrap justify-end gap-2">
          <BaseButton label="Edit" variant="secondary" size="sm" :disabled="clientAction.loading.value" @click="startEditing(row)" />
          <BaseButton
            :label="row.enabled ? 'Disable' : 'Enable'"
            variant="secondary"
            size="sm"
            :disabled="clientAction.loading.value"
            @click="clientAction.run(row, 'toggle')"
          />
          <BaseButton
            v-if="row.client_type === 'confidential'"
            label="Rotate secret"
            variant="secondary"
            size="sm"
            :disabled="clientAction.loading.value"
            @click="clientAction.run(row, 'rotate')"
          />
          <BaseButton label="Delete" variant="ghost" size="sm" :disabled="clientAction.loading.value" @click="pendingDelete = row" />
        </div>
      </template>
    </BaseTable>
  </BaseCard>

  <BaseDialog v-model:visible="createOpen" title="Create app client">
    <form id="create-app-client" class="flex flex-col gap-4" novalidate @submit.prevent="create.run()">
      <BaseAlert v-if="create.error.value && create.error.value.details.length === 0" variant="danger">{{ create.error.value.message }}</BaseAlert>
      <BaseInput v-model="name" label="Name" required hint="For example Web shop or iOS app." :error="create.error.value?.fieldError('name')" />
      <BaseSelect v-model="clientType" label="Type" :options="appClientTypeOptions" />
      <BaseInput
        v-model="origins"
        label="Allowed origins"
        hint="Browser apps only. Separate several with commas, e.g. https://shop.example.com, https://www.shop.example.com"
        :error="create.error.value?.fieldError('allowed_origins')"
      />
      <BaseInput
        v-model="redirectUris"
        label="Redirect URIs"
        :hint="redirectUrisHint"
        :error="create.error.value?.fieldError('redirect_uris')"
      />
      <BaseInput
        v-model="postLogoutUris"
        label="Post-logout redirect URIs"
        :hint="postLogoutUrisHint"
        :error="create.error.value?.fieldError('post_logout_redirect_uris')"
      />
    </form>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="createOpen = false" />
      <BaseButton label="Create" type="submit" form="create-app-client" :loading="create.loading.value" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="editing !== null" title="Edit app client" @update:visible="(open: boolean) => !open && (editing = null)">
    <form id="edit-app-client" class="flex flex-col gap-4" novalidate @submit.prevent="update.run()">
      <BaseAlert v-if="update.error.value && update.error.value.details.length === 0" variant="danger">{{ update.error.value.message }}</BaseAlert>
      <BaseInput v-model="editName" label="Name" required :error="update.error.value?.fieldError('name')" />
      <BaseInput
        v-model="editOrigins"
        label="Allowed origins"
        hint="Browser apps only. Separate several with commas."
        :error="update.error.value?.fieldError('allowed_origins')"
      />
      <BaseInput
        v-model="editRedirectUris"
        label="Redirect URIs"
        :hint="redirectUrisHint"
        :error="update.error.value?.fieldError('redirect_uris')"
      />
      <BaseInput
        v-model="editPostLogoutUris"
        label="Post-logout redirect URIs"
        :hint="postLogoutUrisHint"
        :error="update.error.value?.fieldError('post_logout_redirect_uris')"
      />
    </form>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="editing = null" />
      <BaseButton label="Save" type="submit" form="edit-app-client" :loading="update.loading.value" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="revealed !== null" title="Client details" @update:visible="(open: boolean) => !open && (revealed = null)">
    <dl v-if="revealed" class="grid gap-2 text-sm">
      <dt class="font-medium">Client ID</dt>
      <dd><code class="font-mono text-xs break-all">{{ revealed.uid }}</code></dd>
      <template v-if="revealed.client_secret">
        <dt class="font-medium">Client secret</dt>
        <dd><code class="font-mono text-xs break-all">{{ revealed.client_secret }}</code></dd>
      </template>
    </dl>
    <BaseAlert v-if="revealed?.client_secret" variant="warning" title="Copy the secret now">
      It won't be shown again. Keep it on your server only; never put it in a browser or mobile app.
    </BaseAlert>
    <template #footer>
      <BaseButton label="Done" @click="revealed = null" />
    </template>
  </BaseDialog>

  <BaseDialog :visible="pendingDelete !== null" title="Delete app client?" @update:visible="(open: boolean) => !open && (pendingDelete = null)">
    <p class="text-sm">
      Apps using <strong>{{ pendingDelete?.name }}</strong> will stop being able to sign end users in, and everyone signed in
      through it will be signed out.
    </p>
    <template #footer>
      <BaseButton label="Cancel" variant="secondary" @click="pendingDelete = null" />
      <BaseButton
        label="Delete app client"
        variant="danger"
        :loading="clientAction.loading.value"
        @click="pendingDelete && clientAction.run(pendingDelete, 'delete')"
      />
    </template>
  </BaseDialog>
</template>
