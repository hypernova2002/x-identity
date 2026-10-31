import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'

import LanguageFlag from '../LanguageFlag.vue'

describe('LanguageFlag', () => {
  it('is decorative, since the language is always named beside it', () => {
    expect(mount(LanguageFlag, { props: { locale: 'ja' } }).get('svg').attributes('aria-hidden')).toBe('true')
  })

  it("gives each UK flag its own clip paths, so two on a page don't share them", () => {
    const wrapper = mount({
      components: { LanguageFlag },
      template: '<div><LanguageFlag locale="en" /><LanguageFlag locale="en" /></div>',
    })

    const ids = wrapper.findAll('clipPath').map((clipPath) => clipPath.attributes('id'))

    expect(ids).toHaveLength(4)
    expect(new Set(ids).size).toBe(4)
  })
})
