import { onBeforeUnmount, onMounted, type Ref } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'

import { useConfirmation } from './useConfirmation'
import { i18n } from '@/i18n'

/**
 * Asks before leaving a page while a form has unsaved changes. Closing or reloading the tab can only
 * show the browser's own prompt; browsers don't allow a page's dialog there.
 */
export function useUnsavedChanges(dirty: Ref<boolean>) {
  const confirmation = useConfirmation()

  function warnOnUnload(event: BeforeUnloadEvent) {
    if (!dirty.value) return
    event.preventDefault()
  }

  onBeforeRouteLeave(
    async () =>
      !dirty.value ||
      confirmation({
        title: i18n.global.t('common.unsavedChanges.title'),
        message: i18n.global.t('common.unsavedChanges.message'),
        confirmLabel: i18n.global.t('common.unsavedChanges.confirm'),
        cancelLabel: i18n.global.t('common.unsavedChanges.cancel'),
        danger: true,
      }),
  )
  onMounted(() => window.addEventListener('beforeunload', warnOnUnload))
  onBeforeUnmount(() => window.removeEventListener('beforeunload', warnOnUnload))
}
