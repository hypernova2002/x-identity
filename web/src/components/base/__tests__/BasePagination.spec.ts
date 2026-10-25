import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import OpenVue from 'openvue/config'

import BasePagination from '../BasePagination.vue'

function mountPagination(props: Partial<InstanceType<typeof BasePagination>['$props']>) {
  return mount(BasePagination, {
    props: { page: 1, total: 60, perPage: 25, rowCount: 25, ...props },
    global: { plugins: [[OpenVue, { unstyled: true }]] },
  })
}

describe('BasePagination', () => {
  it('shows the range of rows on this page and the total', () => {
    expect(mountPagination({ page: 2 }).text()).toContain('26–50 of 60')
    expect(mountPagination({ page: 3, rowCount: 10 }).text()).toContain('51–60 of 60')
    expect(mountPagination({ total: 0, rowCount: 0 }).text()).toContain('No results')
  })

  it('pages with 1-based numbers and disables the ends', async () => {
    const wrapper = mountPagination({ page: 1 })

    expect(wrapper.get('button[aria-label="Previous page"]').attributes('disabled')).toBeDefined()
    await wrapper.get('button[aria-label="Next page"]').trigger('click')
    expect(wrapper.emitted('update:page')).toEqual([[2]])
    expect(mountPagination({ page: 3, rowCount: 10 }).get('button[aria-label="Next page"]').attributes('disabled')).toBeDefined()
  })

  it('shows a capped total as a lower bound, keeps Next available past it, and offers an exact count', async () => {
    const wrapper = mountPagination({ page: 400, total: 10000, capped: true })

    expect(wrapper.text()).toContain('9,976–10,000 of 10,000+')
    expect(wrapper.get('button[aria-label="Next page"]').attributes('disabled')).toBeUndefined()

    await wrapper.findAll('button').find((button) => button.text() === 'Count exactly')!.trigger('click')
    expect(wrapper.emitted('countExactly')).toHaveLength(1)
  })
})
