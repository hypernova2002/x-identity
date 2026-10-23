<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import { useAppClient } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AttributeDefinition } from '@/types/api'

const { accountUid, project } = useProjectContext()
const { record: client } = useAppClient()
const attributes = ref<AttributeDefinition[]>([])
const tokenAttributes = computed(() => attributes.value.filter((attribute) => attribute.include_in_token))

const scopes = [
  ['openid', 'Required. Returns an ID token.'],
  ['profile', 'The user\'s name.'],
  ['email', 'The user\'s email and whether it\'s verified.'],
  ['groups', 'Adds a groups claim with the user\'s group names to the ID token and userinfo.'],
  ['offline_access', 'Issues a refresh token. Without it, the app gets none.'],
]

const load = useAsyncAction(async () => {
  if (!project.value) return
  attributes.value = (await projectAdminService.listAttributes(accountUid.value, project.value.uid)).items
})

onMounted(() => load.run())
</script>

<template>
  <BaseCard title="Endpoints" description="Point an OpenID Connect library at the issuer; it finds the rest through discovery.">
    <dl v-if="project" class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">Issuer</dt>
      <dd class="font-mono text-xs break-all">{{ project.token_issuer }}</dd>
      <dt class="font-medium">Discovery</dt>
      <dd class="font-mono text-xs break-all">{{ project.token_issuer }}/.well-known/openid-configuration</dd>
      <dt class="font-medium">JWKS</dt>
      <dd class="font-mono text-xs break-all">{{ project.token_issuer }}/.well-known/jwks.json</dd>
    </dl>
  </BaseCard>

  <BaseCard title="Scopes" description="What the app asks for in the authorization request. The code flow with PKCE is required.">
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <template v-for="[scope, meaning] in scopes" :key="scope">
        <dt class="font-mono text-xs">{{ scope }}</dt>
        <dd>{{ meaning }}</dd>
      </template>
    </dl>
  </BaseCard>

  <BaseCard title="Claims">
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">Access token</dt>
      <dd>
        <code class="font-mono text-xs">iss sub aud exp iat auth_time token_use amr sid jti client_id</code>, plus
        <code class="font-mono text-xs">scope</code> when requested; <code class="font-mono text-xs">aud</code> and
        <code class="font-mono text-xs">client_id</code> are <code class="font-mono text-xs">{{ client.uid }}</code>.
      </dd>
      <dt class="font-medium">ID token</dt>
      <dd>
        <code class="font-mono text-xs">sub email email_verified name custom_attributes</code>, plus <code class="font-mono text-xs">nonce</code>
        when sent and <code class="font-mono text-xs">groups</code> with the groups scope.
      </dd>
      <dt class="font-medium">Custom attributes in tokens</dt>
      <dd>
        <BaseAlert v-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
        <span v-else-if="tokenAttributes.length === 0" class="text-text-muted">None.</span>
        <code v-else class="font-mono text-xs">{{ tokenAttributes.map((attribute) => attribute.key).join(', ') }}</code>
        <RouterLink :to="{ name: 'project-attributes', params: { projectUid: project?.uid } }" class="ml-2 text-sm font-medium text-primary underline">
          Manage attributes
        </RouterLink>
      </dd>
    </dl>
  </BaseCard>

  <BaseCard title="Lifetimes">
    <p class="text-sm">
      Token and session lifetimes are set for the whole project, in
      <RouterLink :to="{ name: 'project-auth-tokens', params: { projectUid: project?.uid } }" class="font-medium text-primary underline">
        Authentication › Tokens and sessions</RouterLink>.
    </p>
  </BaseCard>
</template>
