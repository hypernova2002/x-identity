import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import BasePagination from '../BasePagination.vue'

function mountPagination(props: Partial<InstanceType<typeof BasePagination>['$props']>) {
  return mount(BasePagination, { props: { page: 1, total: 60, perPage: 25, ...props }, global: { plugins: [[OpenVue, { unstyled: true }]] } })
}

const button = (wrapper: ReturnType<typeof mountPagination>, name: string) => wrapper.findAll('button').find((candidate) => candidate.text() === name)!

describe('BasePagination', () => {
  it('shows the page count for exact totals', () => {
    const wrapper = mountPagination({ page: 2 })

    expect(wrapper.text()).toContain('Page 2 of 3 · 60 total')
    expect(wrapper.text()).not.toContain('Count exactly')
  })

  it('shows a capped total as a lower bound, keeps Next available past it, and offers an exact count', async () => {
    const wrapper = mountPagination({ page: 400, total: 10000, perPage: 25, capped: true })

    expect(wrapper.text()).toContain('Page 400 · 10,000+ total')
    expect(button(wrapper, 'Next').attributes('disabled')).toBeUndefined()

    await button(wrapper, 'Count exactly').trigger('click')
    expect(wrapper.emitted('countExactly')).toHaveLength(1)
  })
})
