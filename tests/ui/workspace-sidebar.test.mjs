import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import WorkspaceSidebar from '../../src/components/WorkspaceSidebar.vue'

describe('WorkspaceSidebar', () => {
  it('renders Chinese create controls for projects and threads', () => {
    const wrapper = mount(WorkspaceSidebar, {
      props: {
        projects: [{ id: 'p-1', name: '默认项目', cwd: 'D:\\remote-agent' }],
        threads: [],
        selectedProjectId: 'p-1',
        selectedThreadId: '',
        newProjectName: '',
        newThreadTitle: '',
      },
    })

    expect(wrapper.text()).toContain('新建项目')
    expect(wrapper.text()).toContain('新建会话')
    expect(wrapper.get('[data-new-project-input]').attributes('placeholder')).toContain('项目名称')
    expect(wrapper.get('[data-new-thread-input]').attributes('placeholder')).toContain('例如：修复 502 问题')
  })
})
