import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import MessageList from '../../src/components/MessageList.vue'

describe('MessageList', () => {
  it('renders user and assistant messages with status labels', () => {
    const wrapper = mount(MessageList, {
      props: {
        messages: [
          { id: 'm-1', role: 'user', text: 'hello world', engine: 'codex' },
          { id: 'm-2', role: 'assistant', text: 'Stored reply from fake codex', engine: 'codex' },
        ],
        threadStatus: 'running',
      },
    })

    expect(wrapper.text()).toContain('hello world')
    expect(wrapper.text()).toContain('Stored reply from fake codex')
    expect(wrapper.text()).toContain('运行中')
  })
})
