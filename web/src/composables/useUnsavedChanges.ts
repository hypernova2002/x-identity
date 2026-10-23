import { onBeforeUnmount, onMounted, type Ref } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'

const MESSAGE = 'You have unsaved changes. Leave without saving?'

/** Asks before leaving a page, or closing the tab, while a form has unsaved changes. */
export function useUnsavedChanges(dirty: Ref<boolean>) {
  function warnOnUnload(event: BeforeUnloadEvent) {
    if (!dirty.value) return
    event.preventDefault()
  }

  onBeforeRouteLeave(() => !dirty.value || window.confirm(MESSAGE))
  onMounted(() => window.addEventListener('beforeunload', warnOnUnload))
  onBeforeUnmount(() => window.removeEventListener('beforeunload', warnOnUnload))
}
