import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import ThreadList from '../../src/components/ThreadList.vue'

describe('ThreadList', () => {
  it('renders thread metadata and emits selection', async () => {
    const wrapper = mount(ThreadList, {
      props: {
        threads: [
          {
            id: 't-1',
            title: 'First thread',
            engine: 'codex',
            messageCount: 2,
            updatedAt: '2026-04-01T10:00:00.000Z',
          },
        ],
        selectedThreadId: '',
      },
    })

    expect(wrapper.text()).toContain('First thread')
    expect(wrapper.text()).toContain('codex')
    expect(wrapper.text()).toContain('2 条消息')

    await wrapper.get('[data-thread-id="t-1"]').trigger('click')
    expect(wrapper.emitted('select')).toEqual([['t-1']])
  })
})
