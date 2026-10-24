import { afterEach, describe, expect, it } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { defineComponent, h, ref } from 'vue'
import { createMemoryHistory, createRouter, RouterView } from 'vue-router'
import OpenVue from 'openvue/config'
import ConfirmationService from 'openvue/confirmationservice'

import { useUnsavedChanges } from '../useUnsavedChanges'
import BaseConfirmHost from '@/components/base/BaseConfirmHost.vue'

const dirty = ref(true)
const Form = defineComponent(() => {
  useUnsavedChanges(dirty)
  return () => h('form')
})

async function setUp() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/form', component: Form },
      { path: '/elsewhere', component: { render: () => h('p', 'elsewhere') } },
    ],
  })
  await router.push('/form')
  mount(() => [h(BaseConfirmHost), h(RouterView)], {
    attachTo: document.body,
    global: { plugins: [router, [OpenVue, { unstyled: true }], ConfirmationService] },
  })
  await flushPromises()
  return router
}

const button = (name: string) => [...document.body.querySelectorAll('button')].find((candidate) => candidate.textContent?.trim() === name)

describe('useUnsavedChanges', () => {
  afterEach(() => {
    dirty.value = true
    document.body.innerHTML = ''
  })

  it('asks in the console\'s dialog, and stays when the user keeps editing', async () => {
    const router = await setUp()

    const leaving = router.push('/elsewhere')
    await flushPromises()
    expect(document.body.textContent).toContain('Discard changes?')

    button('Keep editing')!.click()
    await leaving

    expect(router.currentRoute.value.path).toBe('/form')
  })

  it('leaves once the user discards the changes', async () => {
    const router = await setUp()

    const leaving = router.push('/elsewhere')
    await flushPromises()
    button('Discard changes')!.click()
    await leaving

    expect(router.currentRoute.value.path).toBe('/elsewhere')
  })
})
