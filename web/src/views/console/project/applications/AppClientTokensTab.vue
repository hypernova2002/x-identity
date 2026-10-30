<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import { useAppClient } from '@/composables/useApplicationContext'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { AttributeDefinition } from '@/types/api'

const { t } = useI18n()

const { accountUid, project } = useProjectContext()
const { record: client } = useAppClient()
const attributes = ref<AttributeDefinition[]>([])
const tokenAttributes = computed(() => attributes.value.filter((attribute) => attribute.include_in_token))

const scopes = [
  ['openid', t('project.appClientTokens.requiredReturnsAnIdToken')],
  ['profile', t('project.appClientTokens.theUserSName')],
  ['email', t('project.appClientTokens.theUserSEmailAnd')],
  ['groups', t('project.appClientTokens.addsAGroupsClaimWith')],
  ['offline_access', t('project.appClientTokens.issuesARefreshTokenWithout')],
]

const load = useAsyncAction(async () => {
  if (!project.value) return
  attributes.value = (await projectAdminService.listAttributes(accountUid.value, project.value.uid)).items
})

onMounted(() => load.run())
</script>

<template>
  <BaseCard :title="$t('project.appClientTokens.endpoints')" :description="$t('project.appClientTokens.pointAnOpenidConnectLibrary')">
    <dl v-if="project" class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">{{ $t('project.appClientTokens.issuer') }}</dt>
      <dd class="font-mono text-xs break-all">{{ project.token_issuer }}</dd>
      <dt class="font-medium">{{ $t('project.appClientTokens.discovery') }}</dt>
      <dd class="font-mono text-xs break-all">{{ `${project.token_issuer}/.well-known/openid-configuration` }}</dd>
      <dt class="font-medium">{{ $t('project.appClientTokens.jwks') }}</dt>
      <dd class="font-mono text-xs break-all">{{ `${project.token_issuer}/.well-known/jwks.json` }}</dd>
    </dl>
  </BaseCard>

  <BaseCard :title="$t('project.appClientTokens.scopes')" :description="$t('project.appClientTokens.whatTheAppAsksFor')">
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <template v-for="[scope, meaning] in scopes" :key="scope">
        <dt class="font-mono text-xs">{{ scope }}</dt>
        <dd>{{ meaning }}</dd>
      </template>
    </dl>
  </BaseCard>

  <BaseCard :title="$t('project.appClientTokens.claims')">
    <dl class="grid gap-2 text-sm sm:grid-cols-[max-content_1fr]">
      <dt class="font-medium">{{ $t('project.appClientTokens.accessToken') }}</dt>
      <i18n-t keypath="project.appClientTokens.accessTokenClaims" tag="dd">
        <template #claims><code class="font-mono text-xs">{{ $t('project.appClientTokens.issSubAudExpIat') }}</code></template>
        <template #scope><code class="font-mono text-xs">{{ $t('project.appClientTokens.scope') }}</code></template>
        <template #aud><code class="font-mono text-xs">{{ $t('project.appClientTokens.aud') }}</code></template>
        <template #clientId><code class="font-mono text-xs">{{ $t('project.appClientTokens.clientId') }}</code></template>
        <template #uid><code class="font-mono text-xs">{{ client.uid }}</code></template>
      </i18n-t>
      <dt class="font-medium">{{ $t('project.appClientTokens.idToken') }}</dt>
      <i18n-t keypath="project.appClientTokens.idTokenClaims" tag="dd">
        <template #claims><code class="font-mono text-xs">{{ $t('project.appClientTokens.subEmailEmailVerifiedName') }}</code></template>
        <template #nonce><code class="font-mono text-xs">{{ $t('project.appClientTokens.nonce') }}</code></template>
        <template #groups><code class="font-mono text-xs">{{ $t('project.appClientTokens.groups') }}</code></template>
      </i18n-t>
      <dt class="font-medium">{{ $t('project.appClientTokens.customAttributesInTokens') }}</dt>
      <dd>
        <BaseAlert v-if="load.error.value" variant="danger">{{ load.error.value.message }}</BaseAlert>
        <span v-else-if="tokenAttributes.length === 0" class="text-text-muted">{{ $t('project.appClientTokens.none') }}</span>
        <code v-else class="font-mono text-xs">{{ tokenAttributes.map((attribute) => attribute.key).join(', ') }}</code>
        <RouterLink :to="{ name: 'project-attributes', params: { projectUid: project?.uid } }" class="ml-2 text-sm font-medium text-primary underline">
          {{ $t('project.appClientTokens.manageAttributes') }}
        </RouterLink>
      </dd>
    </dl>
  </BaseCard>

  <BaseCard :title="$t('project.appClientTokens.lifetimes')">
    <i18n-t keypath="project.appClientTokens.lifetimesNote" tag="p" class="text-sm">
      <template #link><RouterLink :to="{ name: 'project-auth-tokens', params: { projectUid: project?.uid } }" class="font-medium text-primary underline">
        {{ $t('project.appClientTokens.authenticationTokensAndSessions') }}</RouterLink></template>
    </i18n-t>
  </BaseCard>
</template>
