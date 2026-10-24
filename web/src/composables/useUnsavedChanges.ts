import { onBeforeUnmount, onMounted, type Ref } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'

import { useConfirmation } from './useConfirmation'

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
        title: 'Discard changes?',
        message: "You have changes on this page that haven't been saved. If you leave, they'll be lost.",
        confirmLabel: 'Discard changes',
        cancelLabel: 'Keep editing',
        danger: true,
      }),
  )
  onMounted(() => window.addEventListener('beforeunload', warnOnUnload))
  onBeforeUnmount(() => window.removeEventListener('beforeunload', warnOnUnload))
}
