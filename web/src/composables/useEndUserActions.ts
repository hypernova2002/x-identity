import { ref } from 'vue'

import { useAsyncAction } from './useAsyncAction'
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
        notice = action === 'disable' ? `${endUser.email} was disabled and signed out everywhere.` : `${endUser.email} was enabled.`
        break
      case 'reset_mfa':
        await projectAdminService.resetEndUserMfa(...args)
        updated = { ...endUser, mfa_enabled: false }
        notice = `MFA was turned off for ${endUser.email}.`
        break
      case 'sign_out':
        await projectAdminService.signOutEndUser(...args)
        notice = `${endUser.email} was signed out everywhere.`
        break
      case 'resend_invitation':
        await projectAdminService.resendInvitation(...args)
        notice = `A new invitation was sent to ${endUser.email}.`
        break
      case 'delete':
        await projectAdminService.deleteEndUser(...args)
        updated = null
        notice = `${endUser.email} was deleted.`
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
