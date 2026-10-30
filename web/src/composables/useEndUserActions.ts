import { ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
import { i18n } from '@/i18n'
import { projectAdminService } from '@/services/project'
import type { EndUser } from '@/types/api'

export type EndUserAction = 'disable' | 'enable' | 'reset_mfa' | 'sign_out' | 'resend_invitation' | 'delete'

/** Actions that change access or credentials are confirmed first; the rest run straight away. */
export const CONFIRMED_ACTIONS: readonly EndUserAction[] = ['disable', 'reset_mfa', 'sign_out', 'delete']

export interface EndUserActionResult {
  action: EndUserAction
  endUser: EndUser
  /** The updated user, or null when it was deleted. */
  updated: EndUser | null
  notice: string
}

/** Admin actions on end users, shared by the directory and the end user page. */
export function useEndUserActions(target: () => { accountUid: string; projectUid: string } | null, onDone: (result: EndUserActionResult) => void) {
  const { t } = i18n.global
  const pending = ref<{ action: EndUserAction; endUser: EndUser } | null>(null)

  const perform = useAsyncAction(async (action: EndUserAction, endUser: EndUser) => {
    const ids = target()
    if (!ids) return
    const args = [ids.accountUid, ids.projectUid, endUser.uid] as const

    let updated: EndUser | null = endUser
    let notice = ''
    switch (action) {
      case 'disable':
      case 'enable':
        updated = await projectAdminService.updateEndUser(...args, { status: action === 'disable' ? 'disabled' : 'active' })
        notice = t(action === 'disable' ? 'project.endUserActions.disabled' : 'project.endUserActions.enabled', { email: endUser.email })
        break
      case 'reset_mfa':
        await projectAdminService.resetEndUserMfa(...args)
        updated = { ...endUser, mfa_enabled: false }
        notice = t('project.endUserActions.mfaReset', { email: endUser.email })
        break
      case 'sign_out':
        await projectAdminService.signOutEndUser(...args)
        notice = t('project.endUserActions.signedOut', { email: endUser.email })
        break
      case 'resend_invitation':
        await projectAdminService.resendInvitation(...args)
        notice = t('project.endUserActions.invitationSent', { email: endUser.email })
        break
      case 'delete':
        await projectAdminService.deleteEndUser(...args)
        updated = null
        notice = t('project.endUserActions.deleted', { email: endUser.email })
        break
    }
    pending.value = null
    onDone({ action, endUser, updated, notice })
  })

  /** Asks for confirmation when the action needs it, otherwise runs it. */
  function request(action: EndUserAction, endUser: EndUser) {
    perform.error.value = null
    if (CONFIRMED_ACTIONS.includes(action)) pending.value = { action, endUser }
    else perform.run(action, endUser)
  }

  function confirm() {
    return pending.value ? perform.run(pending.value.action, pending.value.endUser) : Promise.resolve()
  }

  return { pending, perform, request, confirm }
}
