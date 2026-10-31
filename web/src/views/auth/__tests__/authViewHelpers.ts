import { flushPromises, mount, type VueWrapper } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createMemoryHistory, createRouter } from 'vue-router'
import OpenVue from 'openvue/config'
import type { Component } from 'vue'

const Empty = { template: '<div />' }

/**
 * Mounts an account page at `path` through a RouterView, with the routes it links and redirects to,
 * so navigating away unmounts it as it does in the app.
 */
export async function mountAuthView(view: Component, path: string) {
  const pinia = createPinia()
  setActivePinia(pinia)
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/sign-in', component: Empty },
      { path: '/console', component: Empty },
      { path: '/console/security', component: Empty },
      { path: '/console/welcome', name: 'welcome', component: Empty },
      { path: '/:slug/sign-in', name: 'sign-in', component: view },
      { path: '/:slug/forgot-password', name: 'forgot-password', component: Empty },
      { path: '/:slug/accept-invitation', name: 'accept-invitation', component: view },
      { path: '/sign-up', name: 'sign-up', component: view },
    ],
  })
  await router.push(path)
  const wrapper = mount({ template: '<RouterView />' }, { global: { plugins: [pinia, router, [OpenVue, { unstyled: true }]] } })
  await flushPromises()
  return { wrapper, router }
}

/** The input labelled `label` (a label's text starts with it; required fields add "(required)"). */
export function field(wrapper: VueWrapper, label: string) {
  const labelElement = wrapper.findAll('label').find((candidate) => candidate.text().startsWith(label))
  if (!labelElement) throw new Error(`No field labelled ${label}`)
  return wrapper.get(`#${labelElement.attributes('for')}`)
}

export function button(wrapper: VueWrapper, name: string) {
  const found = wrapper.findAll('button').find((candidate) => candidate.text() === name)
  if (!found) throw new Error(`No button named ${name}`)
  return found
}

export async function submit(wrapper: VueWrapper, name: string) {
  await button(wrapper, name).trigger('submit')
  await flushPromises()
}
