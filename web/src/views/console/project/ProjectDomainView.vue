<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
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
    ...domain.saml_apps.map((app) => ({ ...app, kind: 'SAML app', to: { name: 'project-saml-app-credentials', params: { projectUid, samlAppUid: app.uid } } })),
    ...domain.saml_identity_providers.map((provider) => ({
      ...provider,
      kind: 'SAML identity provider',
      to: { name: 'project-identity-provider', params: { projectUid, providerUid: provider.uid } },
    })),
  ]
}

const onRemovedDomain = computed(() => (pendingRemoval.value ? connections(pendingRemoval.value).filter((connection) => connection.on_custom_domain) : []))

function status(domain: ProjectDomain): { tone: StatusTone; label: string } {
  if (domain.status === 'failed') return { tone: 'danger', label: 'Verification failed' }
  if (domain.status === 'pending') return { tone: 'warning', label: 'Waiting for DNS' }
  if (domain.dns_missing_since) return { tone: 'warning', label: 'DNS records missing' }
  return { tone: 'success', label: 'Verified' }
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
  <BaseAlert v-if="!access.admin" variant="info">Only project and account admins can change the custom domain.</BaseAlert>
  <BaseAlert v-if="domains.error.value" variant="danger" title="We couldn't load the custom domain">
    {{ domains.error.value.message }}
    <BaseButton label="Try again" variant="ghost" size="sm" @click="domains.reload()" />
  </BaseAlert>
  <BaseAlert v-if="check.error.value" variant="danger">{{ check.error.value.message }}</BaseAlert>
  <p v-if="domains.loading.value && !domains.data.value" class="text-sm text-text-muted" role="status">Loading…</p>

  <BaseCard v-for="domain in ordered" :key="domain.uid">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div class="flex min-w-0 flex-col gap-1">
        <h2 class="text-lg font-semibold break-all">{{ domain.hostname }}</h2>
        <p class="text-sm text-text-muted">
          <template v-if="domain.status === 'verified'">
            {{ domain === current && settingUp ? 'In use until its replacement is verified.' : 'In use.' }} Verified {{ formatDateTime(domain.verified_at) }}.
          </template>
          <template v-else-if="domain.status === 'pending'">
            Create the DNS records below. We check them automatically until {{ formatDateTime(domain.verify_until) }}{{ current ? `, then this domain replaces ${current.hostname}` : '' }}.
          </template>
          <template v-else>We stopped checking this domain. Fix its DNS records and check again, or remove it.</template>
        </p>
      </div>
      <StatusBadge :tone="status(domain).tone" :label="status(domain).label" />
    </div>

    <BaseAlert v-if="domain.status === 'verified' && domain.dns_missing_since" variant="warning" title="DNS records missing">
      Since {{ formatDateTime(domain.dns_missing_since) }}: {{ domain.check_error }} Restore the records below so the domain keeps working.
    </BaseAlert>
    <BaseAlert v-else-if="domain.status === 'failed'" variant="danger" title="Verification failed">{{ domain.check_error }}</BaseAlert>
    <p v-else-if="domain.status === 'pending' && domain.check_error" class="text-sm text-text-muted">
      Last checked {{ formatDateTime(domain.last_checked_at) }}: {{ domain.check_error }}
    </p>

    <div class="overflow-x-auto rounded-lg border border-border">
      <table class="w-full border-collapse text-left text-sm">
        <caption class="sr-only">DNS records for {{ domain.hostname }}</caption>
        <thead class="bg-bg-subtle">
          <tr>
            <th scope="col" class="px-4 py-3 font-semibold">Type</th>
            <th scope="col" class="px-4 py-3 font-semibold">Name</th>
            <th scope="col" class="px-4 py-3 font-semibold">Value</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="record in domain.dns_records" :key="record.type" class="border-t border-border">
            <td class="px-4 py-3 align-middle font-medium">{{ record.type }}</td>
            <td class="px-4 py-3 align-middle">
              <span class="flex items-center gap-1">
                <code class="font-mono text-xs break-all">{{ record.name }}</code>
                <CopyButton :value="record.name" :label="`${record.type} record name`" />
              </span>
            </td>
            <td class="px-4 py-3 align-middle">
              <span class="flex items-center gap-1">
                <code class="font-mono text-xs break-all">{{ record.value }}</code>
                <CopyButton :value="record.value" :label="`${record.type} record value`" />
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="text-xs text-text-muted">
      Keep both records while the domain is in use. HTTPS certificates for it are set up by your x-identity operator.
    </p>

    <section v-if="domain.status === 'verified' && connections(domain).length > 0" class="flex flex-col gap-2" aria-labelledby="saml-connections">
      <h3 id="saml-connections" class="text-sm font-semibold">SAML apps and identity providers</h3>
      <p class="text-sm text-text-muted">
        Their entity IDs and URLs are set separately, because the other side has them saved. Switch each one on its page, then update its other side.
      </p>
      <ul class="flex flex-col divide-y divide-border rounded-lg border border-border">
        <li v-for="connection in connections(domain)" :key="connection.uid" class="flex flex-wrap items-center justify-between gap-2 px-4 py-2 text-sm">
          <span class="flex flex-col">
            <RouterLink :to="connection.to" class="font-medium text-primary underline-offset-2 hover:underline">{{ connection.name }}</RouterLink>
            <span class="text-xs text-text-muted">{{ connection.kind }}</span>
          </span>
          <StatusBadge
            :tone="connection.on_custom_domain ? 'success' : 'neutral'"
            :label="connection.on_custom_domain ? `Uses ${domain.hostname}` : 'Uses the standard URLs'"
          />
        </li>
      </ul>
    </section>

    <div v-if="access.admin" class="flex flex-wrap gap-2">
      <BaseButton
        label="Check now"
        variant="secondary"
        :loading="checkingUid === domain.uid"
        :disabled="checkingUid !== null"
        @click="check.run(domain)"
      />
      <BaseButton label="Remove domain" variant="ghost" @click="pendingRemoval = domain" />
    </div>
  </BaseCard>

  <BaseCard
    v-if="access.admin && domains.data.value && !settingUp"
    :title="current ? 'Replace the custom domain' : 'Add a custom domain'"
    :description="
      current
        ? `The new domain is checked while ${current.hostname} keeps working, and replaces it once verified. SAML apps and identity providers using ${current.hostname} then move to it, and need their other side updated.`
        : 'Use a subdomain you control. Apps keep using their current URLs until you switch them.'
    "
  >
    <form class="flex flex-wrap items-end gap-3" novalidate @submit.prevent="add.run()">
      <div class="w-full sm:w-80">
        <BaseInput
          v-model="hostname"
          label="Domain"
          placeholder="login.example.com"
          autocomplete="off"
          :error="add.error.value?.fieldError('hostname')"
        />
      </div>
      <BaseButton type="submit" :label="current ? 'Add replacement' : 'Add domain'" :loading="add.loading.value" :disabled="hostname.trim() === ''" />
    </form>
    <BaseAlert v-if="add.error.value && !add.error.value.fieldError('hostname')" variant="danger">
      {{ add.error.value.message }}
    </BaseAlert>
  </BaseCard>

  <ConfirmDialog
    :visible="pendingRemoval !== null"
    :title="`Remove ${pendingRemoval?.hostname ?? 'the domain'}?`"
    confirm-label="Remove domain"
    danger
    :loading="remove.loading.value"
    :error="remove.error.value"
    @update:visible="(open: boolean) => !open && (pendingRemoval = null)"
    @confirm="remove.run()"
  >
    <template v-if="pendingRemoval?.status === 'verified'">
      <p>
        Hosted login and endpoints stop being served on <strong>{{ pendingRemoval.hostname }}</strong>. Apps using it must switch back to the
        project's standard URLs.
      </p>
      <BaseAlert v-if="onRemovedDomain.length > 0" variant="warning" title="These go back to the standard URLs">
        Sign-ins through them fail until their other side is updated with the standard URLs:
        <ul class="mt-1 list-disc pl-5">
          <li v-for="connection in onRemovedDomain" :key="connection.uid">{{ connection.name }} ({{ connection.kind }})</li>
        </ul>
      </BaseAlert>
    </template>
    <p v-else>
      <strong>{{ pendingRemoval?.hostname }}</strong> stops being checked. You can add it again later.
    </p>
  </ConfirmDialog>
</template>
