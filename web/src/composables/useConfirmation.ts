import { useConfirm } from 'openvue/useconfirm'
import { i18n } from '@/i18n'

export interface ConfirmationRequest {
  title: string
  message: string
  confirmLabel: string
  cancelLabel?: string
  /** For actions that lose work or can't be undone. */
  danger?: boolean
}

/**
 * Asks the user to confirm in the console's own dialog (BaseConfirmHost), instead of the browser's
 * confirm box. Resolves true when they confirm, false when they cancel or dismiss it.
 */
export function useConfirmation() {
  const confirm = useConfirm()

  return function confirmation(request: ConfirmationRequest): Promise<boolean> {
    return new Promise((resolve) => {
      let answered = false
      const answer = (value: boolean) => {
        if (answered) return
        answered = true
        resolve(value)
      }
      confirm.require({
        header: request.title,
        message: request.message,
        acceptLabel: request.confirmLabel,
        rejectLabel: request.cancelLabel ?? i18n.global.t('common.actions.cancel'),
        acceptProps: { danger: request.danger ?? false },
        accept: () => answer(true),
        reject: () => answer(false),
        onHide: () => answer(false),
      })
    })
  }
}
