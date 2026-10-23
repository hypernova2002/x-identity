<script setup lang="ts">
import { ref } from 'vue'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseDialog from '@/components/base/BaseDialog.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import { useAppClient } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'

const { accountUid, project, access } = useProjectContext()
const { record: client, replace } = useAppClient()

const rotateOpen = ref(false)
const newSecret = ref<string | null>(null)

const rotate = useAsyncAction(async () => {
  if (!project.value) return
  const rotated = await projectAdminService.rotateAppClientSecret(accountUid.value, project.value.uid, client.value.uid)
  newSecret.value = rotated.client_secret
  replace(rotated)
  rotateOpen.value = false
})
</script>

<template>
  <BaseCard title="Client ID" description="Apps send it as client_id. It isn't secret.">
    <code class="font-mono text-sm break-all">{{ client.uid }}</code>
  </BaseCard>

  <BaseCard v-if="client.client_type === 'public'" title="No client secret">
    <p class="text-sm">
      Public clients run in browsers and on devices, where a secret can't be kept, so they don't have one. They prove themselves
      with PKCE, which x-identity requires for every client. The client type can't be changed; create a confidential client for a
      server-side app.
    </p>
  </BaseCard>

  <BaseCard v-else title="Client secret" description="Confidential clients send it when redeeming codes and refreshing tokens. Only a digest is stored, so it can't be shown again.">
    <BaseAlert v-if="rotate.error.value" variant="danger">{{ rotate.error.value.message }}</BaseAlert>
    <BaseButton v-if="access.developer" label="Rotate secret" variant="secondary" class="self-start" @click="rotateOpen = true" />
    <BaseAlert v-else variant="info">Only project admins and developers can rotate the secret.</BaseAlert>
  </BaseCard>

  <ConfirmDialog v-model:visible="rotateOpen" title="Rotate the client secret?" confirm-label="Rotate secret" danger :loading="rotate.loading.value" :error="rotate.error.value" @confirm="rotate.run()">
    <p>
      The current secret stops working immediately, so <strong>{{ client.name }}</strong> can't sign users in until its server is
      updated with the new one. Existing sessions stay valid, but the app needs the new secret to refresh them.
    </p>
  </ConfirmDialog>

  <BaseDialog :visible="newSecret !== null" title="Copy the new secret" @update:visible="(open: boolean) => !open && (newSecret = null)">
    <code class="font-mono text-xs break-all">{{ newSecret }}</code>
    <BaseAlert variant="warning" title="It won't be shown again">Keep it on your server only; never put it in a browser or mobile app.</BaseAlert>
    <template #footer>
      <BaseButton label="I've copied it" @click="newSecret = null" />
    </template>
  </BaseDialog>
</template>
