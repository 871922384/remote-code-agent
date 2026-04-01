import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import MobileSidebar from '../../src/components/MobileSidebar.vue'

describe('MobileSidebar', () => {
  it('shows drawer content when opened', () => {
    const wrapper = mount(MobileSidebar, {
      props: {
        open: true,
      },
      slots: {
        default: '<div class="drawer-probe">drawer body</div>',
      },
    })

    expect(wrapper.find('[data-mobile-drawer]').classes()).toContain('is-open')
    expect(wrapper.text()).toContain('drawer body')
  })
})
