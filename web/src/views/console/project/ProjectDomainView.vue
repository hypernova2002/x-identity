<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'

import BaseAlert from '@/components/base/BaseAlert.vue'
import BaseButton from '@/components/base/BaseButton.vue'
import BaseCard from '@/components/base/BaseCard.vue'
import BaseInput from '@/components/base/BaseInput.vue'
import ConfirmDialog from '@/components/console/ConfirmDialog.vue'
import CopyButton from '@/components/console/CopyButton.vue'
import StatusBadge, { type StatusTone } from '@/components/console/StatusBadge.vue'
import { useAsync } from '@/composables/useAsync'
import { useAsyncAction } from '@/composables/useAsyncAction'
import { useProjectContext } from '@/composables/useProjectContext'
import { projectAdminService } from '@/services/project'
import type { ProjectDomain, SamlConnection } from '@/types/api'
import { formatDateTime } from '@/utils/format'

const { t, te } = useI18n()

const { accountUid, project, access } = useProjectContext()

const hostname = ref('')
const pendingRemoval = ref<ProjectDomain | null>(null)
const checkingUid = ref<string | null>(null)

const domains = useAsync(() => projectAdminService.listDomains(accountUid.value, project.value!.uid))

const current = computed(() => domains.data.value?.find((domain) => domain.status === 'verified') ?? null)
const settingUp = computed(() => domains.data.value?.find((domain) => domain.status !== 'verified') ?? null)
const ordered = computed(() => [current.value, settingUp.value].filter((domain): domain is ProjectDomain => domain !== null))

interface ConnectionLink extends SamlConnection {
  kind: string
  to: { name: string; params: Record<string, string> }
}

/** The project's SAML apps and identity providers, with where each one's settings are. */
function connections(domain: ProjectDomain): ConnectionLink[] {
  const projectUid = project.value?.uid ?? ''
  return [
    ...domain.saml_apps.map((app) => ({ ...app, kind: t('project.projectDomain.samlApp'), to: { name: 'project-saml-app-credentials', params: { projectUid, samlAppUid: app.uid } } })),
    ...domain.saml_identity_providers.map((provider) => ({
      ...provider,
      kind: t('project.projectDomain.samlIdentityProvider'),
      to: { name: 'project-identity-provider', params: { projectUid, providerUid: provider.uid } },
    })),
  ]
}

const onRemovedDomain = computed(() => (pendingRemoval.value ? connections(pendingRemoval.value).filter((connection) => connection.on_custom_domain) : []))

/** What the last DNS check found wrong, from its code. */
function checkError(domain: ProjectDomain): string {
  const key = `project.projectDomain.checkErrors.${domain.check_error}`
  return te(key) ? t(key, domain.check_error_params) : t('project.projectDomain.checkErrorUnknown')
}

function status(domain: ProjectDomain): { tone: StatusTone; label: string } {
  if (domain.status === 'failed') return { tone: 'danger', label: t('project.projectDomain.verificationFailed') }
  if (domain.status === 'pending') return { tone: 'warning', label: t('project.projectDomain.waitingForDns') }
  if (domain.dns_missing_since) return { tone: 'warning', label: t('project.projectDomain.dnsRecordsMissing') }
  return { tone: 'success', label: t('project.projectDomain.verified') }
}

const add = useAsyncAction(async () => {
  await projectAdminService.addDomain(accountUid.value, project.value!.uid, hostname.value.trim())
  hostname.value = ''
  await domains.reload()
})

const check = useAsyncAction(async (domain: ProjectDomain) => {
  checkingUid.value = domain.uid
  try {
    await projectAdminService.checkDomain(accountUid.value, project.value!.uid, domain.uid)
    await domains.reload()
  } finally {
    checkingUid.value = null
  }
})

const remove = useAsyncAction(async () => {
  if (!pendingRemoval.value) return
  await projectAdminService.removeDomain(accountUid.value, project.value!.uid, pendingRemoval.value.uid)
  pendingRemoval.value = null
  await domains.reload()
})

onMounted(() => domains.reload())
</script>

<template>
  <BaseAlert v-if="!access.admin" variant="info">{{ $t('project.projectDomain.onlyProjectAndAccountAdmins') }}</BaseAlert>
  <BaseAlert v-if="domains.error.value" variant="danger" :title="$t('project.projectDomain.weCouldnTLoadThe')">
    {{ domains.error.value.message }}
    <BaseButton :label="$t('project.projectDomain.tryAgain')" variant="ghost" size="sm" @click="domains.reload()" />
  </BaseAlert>
  <BaseAlert v-if="check.error.value" variant="danger">{{ check.error.value.message }}</BaseAlert>
  <p v-if="domains.loading.value && !domains.data.value" class="text-sm text-text-muted" role="status">{{ $t('project.projectDomain.loading') }}</p>

  <BaseCard v-for="domain in ordered" :key="domain.uid">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div class="flex min-w-0 flex-col gap-1">
        <h2 class="text-lg font-semibold break-all">{{ domain.hostname }}</h2>
        <p class="text-sm text-text-muted">
          <template v-if="domain.status === 'verified'">
            {{
              $t(domain === current && settingUp ? 'project.projectDomain.inUseUntilReplacedVerified' : 'project.projectDomain.inUseVerified', {
                date: formatDateTime(domain.verified_at),
              })
            }}
          </template>
          <template v-else-if="domain.status === 'pending'">
            {{
              current
                ? $t('project.projectDomain.createRecordsReplacing', { date: formatDateTime(domain.verify_until), hostname: current.hostname })
                : $t('project.projectDomain.createRecords', { date: formatDateTime(domain.verify_until) })
            }}
          </template>
          <template v-else>{{ $t('project.projectDomain.weStoppedCheckingThisDomain') }}</template>
        </p>
      </div>
      <StatusBadge :tone="status(domain).tone" :label="status(domain).label" />
    </div>

    <BaseAlert v-if="domain.status === 'verified' && domain.dns_missing_since" variant="warning" :title="$t('project.projectDomain.dnsRecordsMissing')">
      {{ $t('project.projectDomain.recordsMissingSince', { date: formatDateTime(domain.dns_missing_since), problem: checkError(domain) }) }}
    </BaseAlert>
    <BaseAlert v-else-if="domain.status === 'failed'" variant="danger" :title="$t('project.projectDomain.verificationFailed')">{{ checkError(domain) }}</BaseAlert>
    <p v-else-if="domain.status === 'pending' && domain.check_error" class="text-sm text-text-muted">
      {{ $t('project.projectDomain.lastChecked', { date: formatDateTime(domain.last_checked_at), problem: checkError(domain) }) }}
    </p>

    <div class="overflow-x-auto rounded-lg border border-border">
      <table class="w-full border-collapse text-left text-sm">
        <caption class="sr-only">{{ $t('project.projectDomain.recordsCaption', { hostname: domain.hostname }) }}</caption>
        <thead class="bg-bg-subtle">
          <tr>
            <th scope="col" class="px-4 py-3 font-semibold">{{ $t('project.projectDomain.type') }}</th>
            <th scope="col" class="px-4 py-3 font-semibold">{{ $t('project.projectDomain.name') }}</th>
            <th scope="col" class="px-4 py-3 font-semibold">{{ $t('project.projectDomain.value') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="record in domain.dns_records" :key="record.type" class="border-t border-border">
            <td class="px-4 py-3 align-middle font-medium">{{ record.type }}</td>
            <td class="px-4 py-3 align-middle">
              <span class="flex items-center gap-1">
                <code class="font-mono text-xs break-all">{{ record.name }}</code>
                <CopyButton :value="record.name" :label="$t('project.projectDomain.recordName', { type: record.type })" />
              </span>
            </td>
            <td class="px-4 py-3 align-middle">
              <span class="flex items-center gap-1">
                <code class="font-mono text-xs break-all">{{ record.value }}</code>
                <CopyButton :value="record.value" :label="$t('project.projectDomain.recordValue', { type: record.type })" />
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="text-xs text-text-muted">
      {{ $t('project.projectDomain.keepBothRecordsWhileThe') }}
    </p>

    <section v-if="domain.passkey_related_origins.length > 0" class="flex flex-col gap-2" aria-labelledby="passkey-origins">
      <h3 id="passkey-origins" class="text-sm font-semibold">{{ $t('project.projectDomain.appsThatCanUseIts') }}</h3>
      <p class="text-sm text-text-muted">{{ $t('project.projectDomain.publishedIn', { url: `${domain.hostname}/.well-known/webauthn` }) }}</p>
      <ul class="flex flex-col gap-1">
        <li v-for="origin in domain.passkey_related_origins" :key="origin"><code class="font-mono text-xs break-all">{{ origin }}</code></li>
      </ul>
    </section>

    <section v-if="domain.status === 'verified' && connections(domain).length > 0" class="flex flex-col gap-2" aria-labelledby="saml-connections">
      <h3 id="saml-connections" class="text-sm font-semibold">{{ $t('project.projectDomain.samlAppsAndIdentityProviders') }}</h3>
      <p class="text-sm text-text-muted">
        {{ $t('project.projectDomain.theirEntityIdsAndUrls') }}
      </p>
      <ul class="flex flex-col divide-y divide-border rounded-lg border border-border">
        <li v-for="connection in connections(domain)" :key="connection.uid" class="flex flex-wrap items-center justify-between gap-2 px-4 py-2 text-sm">
          <span class="flex flex-col">
            <RouterLink :to="connection.to" class="font-medium text-primary underline-offset-2 hover:underline">{{ connection.name }}</RouterLink>
            <span class="text-xs text-text-muted">{{ connection.kind }}</span>
          </span>
          <StatusBadge
            :tone="connection.on_custom_domain ? 'success' : 'neutral'"
            :label="connection.on_custom_domain ? $t('project.projectDomain.uses', { hostname: domain.hostname }) : $t('project.projectDomain.usesTheStandardUrls')"
          />
        </li>
      </ul>
    </section>

    <div v-if="access.admin" class="flex flex-wrap gap-2">
      <BaseButton
        :label="$t('project.projectDomain.checkNow')"
        variant="secondary"
        :loading="checkingUid === domain.uid"
        :disabled="checkingUid !== null"
        @click="check.run(domain)"
      />
      <BaseButton :label="$t('project.projectDomain.removeDomain')" variant="ghost" @click="pendingRemoval = domain" />
    </div>
  </BaseCard>

  <BaseCard
    v-if="access.admin && domains.data.value && !settingUp"
    :title="current ? $t('project.projectDomain.replaceTheCustomDomain') : $t('project.projectDomain.addACustomDomain')"
    :description="
      current
        ? [
            $t('project.projectDomain.theNewDomainIsChecked', { hostname: current.hostname }),
            current.passkey_count > 0 ? $t('project.projectDomain.endUserPasskeysMove', { hostname: current.hostname }, current.passkey_count) : '',
          ].join(' ').trim()
        : $t('project.projectDomain.useASubdomainYouControl')
    "
  >
    <form class="flex flex-wrap items-end gap-3" novalidate @submit.prevent="add.run()">
      <div class="w-full sm:w-80">
        <BaseInput
          v-model="hostname"
          :label="$t('project.projectDomain.domain')"
          :placeholder="'login.example.com'"
          autocomplete="off"
          :error="add.error.value?.fieldError('hostname')"
        />
      </div>
      <BaseButton type="submit" :label="current ? $t('project.projectDomain.addReplacement') : $t('project.projectDomain.addDomain')" :loading="add.loading.value" :disabled="hostname.trim() === ''" />
    </form>
    <BaseAlert v-if="add.error.value && !add.error.value.fieldError('hostname')" variant="danger">
      {{ add.error.value.message }}
    </BaseAlert>
  </BaseCard>

  <ConfirmDialog
    :visible="pendingRemoval !== null"
    :title="$t('project.projectDomain.remove', { domain: pendingRemoval?.hostname ?? $t('project.projectDomain.removeFallback') })"
    :confirm-label="$t('project.projectDomain.removeDomain')"
    danger
    :loading="remove.loading.value"
    :error="remove.error.value"
    @update:visible="(open: boolean) => !open && (pendingRemoval = null)"
    @confirm="remove.run()"
  >
    <template v-if="pendingRemoval?.status === 'verified'">
      <i18n-t keypath="project.projectDomain.removeVerified" tag="p">
        <template #hostname><strong>{{ pendingRemoval.hostname }}</strong></template>
      </i18n-t>
      <BaseAlert v-if="pendingRemoval.passkey_count > 0" variant="warning" :title="$t('project.projectDomain.passkeysStopWorking')">
        {{ $t('project.projectDomain.removePasskeys', { hostname: pendingRemoval.hostname }, pendingRemoval.passkey_count) }}
      </BaseAlert>
      <BaseAlert v-if="onRemovedDomain.length > 0" variant="warning" :title="$t('project.projectDomain.theseGoBackToThe')">
        {{ $t('project.projectDomain.signInsThroughThemFail') }}
        <ul class="mt-1 list-disc pl-5">
          <li v-for="connection in onRemovedDomain" :key="connection.uid">{{ connection.name }} ({{ connection.kind }})</li>
        </ul>
      </BaseAlert>
    </template>
    <i18n-t v-else keypath="project.projectDomain.removeUnverified" tag="p">
      <template #hostname><strong>{{ pendingRemoval?.hostname }}</strong></template>
    </i18n-t>
  </ConfirmDialog>
</template>
