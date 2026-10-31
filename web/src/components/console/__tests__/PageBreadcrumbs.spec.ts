import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import { createMemoryHistory, createRouter } from 'vue-router'

import PageBreadcrumbs from '../PageBreadcrumbs.vue'

describe('PageBreadcrumbs', () => {
  it('links each level above the current page, which is marked and not a link', async () => {
    const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/:path(.*)*', component: { template: '<div />' } }] })
    await router.push('/')
    const wrapper = mount(PageBreadcrumbs, {
      props: { items: [{ label: 'End users', to: '/end-users' }, { label: 'casey@shop.test', to: '/end-users/eu_1' }] },
      global: { plugins: [router] },
    })

    expect(wrapper.get('nav').attributes('aria-label')).toBe('Breadcrumb')
    expect(wrapper.findAll('a').map((link) => [link.text(), link.attributes('href')])).toEqual([['End users', '/end-users']])
    expect(wrapper.get('[aria-current="page"]').text()).toBe('casey@shop.test')
  })
})
