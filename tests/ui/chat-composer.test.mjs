import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import ChatComposer from '../../src/components/ChatComposer.vue'

describe('ChatComposer', () => {
  it('switches between send and stop states', async () => {
    const wrapper = mount(ChatComposer, {
      props: {
        disabled: false,
        busy: false,
        selectedEngine: 'codex',
      },
    })

    await wrapper.get('textarea').setValue('hello')
    await wrapper.get('form').trigger('submit.prevent')

    expect(wrapper.emitted('submit')).toEqual([
      [{ prompt: 'hello', engine: 'codex' }],
    ])

    await wrapper.setProps({ busy: true })
    expect(wrapper.get('[data-action-button]').text()).toContain('停止')
  })

  it('shows a Chinese disabled hint when no thread is selected', () => {
    const wrapper = mount(ChatComposer, {
      props: {
        disabled: true,
        busy: false,
        selectedEngine: 'codex',
      },
    })

    expect(wrapper.text()).toContain('请先创建或选择一个会话')
  })
})
