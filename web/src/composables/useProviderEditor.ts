import { ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
import { projectAdminService } from '@/services/project'
import type { IdentityProvider, IdentityProviderKind } from '@/types/api'
import { emptyProviderDraft, providerDraftFrom, providerInputFrom, withProviderMetadata, type IdentityProviderDraft } from '@/utils/identityProviders'

/** Adding or editing an identity provider in a dialog. */
export function useProviderEditor(target: () => { accountUid: string; projectUid: string } | null) {
  const open = ref(false)
  const editing = ref<IdentityProvider | null>(null)
  const draft = ref<IdentityProviderDraft>(emptyProviderDraft('google'))

  function start(provider: IdentityProvider | null, kind: IdentityProviderKind = 'google') {
    editing.value = provider
    draft.value = provider ? providerDraftFrom(provider) : emptyProviderDraft(kind)
    save.error.value = null
    importMetadata.error.value = null
    open.value = true
  }

  const importMetadata = useAsyncAction(async (source: { metadata_xml: string } | { metadata_url: string }) => {
    const ids = target()
    if (!ids) return
    draft.value = withProviderMetadata(draft.value, await projectAdminService.parseSamlProviderMetadata(ids.accountUid, ids.projectUid, source))
  })

  const save = useAsyncAction(async (): Promise<IdentityProvider | undefined> => {
    const ids = target()
    if (!ids) return undefined
    const input = providerInputFrom(draft.value)
    const saved = editing.value
      ? await projectAdminService.updateIdentityProvider(ids.accountUid, ids.projectUid, editing.value.uid, input)
      : await projectAdminService.createIdentityProvider(ids.accountUid, ids.projectUid, draft.value.kind, input)
    open.value = false
    return saved
  })

  return { open, editing, draft, start, importMetadata, save }
}
