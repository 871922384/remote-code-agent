import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import ProjectList from '../../src/components/ProjectList.vue'

describe('ProjectList', () => {
  it('renders projects and highlights the selected project', () => {
    const wrapper = mount(ProjectList, {
      props: {
        projects: [
          { id: 'p-1', name: 'Alpha Workspace', cwd: 'D:\\remote-agent' },
          { id: 'p-2', name: 'Beta Workspace', cwd: 'D:\\apps\\beta' },
        ],
        selectedProjectId: 'p-2',
      },
    })

    expect(wrapper.text()).toContain('Alpha Workspace')
    expect(wrapper.text()).toContain('Beta Workspace')
    expect(wrapper.get('[data-project-id="p-2"]').classes()).toContain('is-selected')
  })
})
