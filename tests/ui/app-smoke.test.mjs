import { mount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import App from '../../src/App.vue'

function jsonResponse(payload, status = 200) {
  return Promise.resolve({
    ok: status >= 200 && status < 300,
    status,
    json: () => Promise.resolve(payload),
  })
}

function sseResponse(events) {
  const encoder = new TextEncoder()
  let index = 0

  return Promise.resolve({
    ok: true,
    status: 200,
    body: {
      getReader() {
        return {
          read() {
            if (index >= events.length) {
              return Promise.resolve({ done: true, value: undefined })
            }

            const value = encoder.encode(`data: ${JSON.stringify(events[index])}\n\n`)
            index += 1
            return Promise.resolve({ done: false, value })
          },
          cancel() {
            return Promise.resolve()
          },
        }
      },
    },
  })
}

describe('App smoke flow', () => {
  beforeEach(() => {
    window.localStorage.clear()
  })

  it('authenticates, creates project/thread, sends messages for both engines, and interrupts a run', async () => {
    const fetchMock = vi.fn()
      .mockImplementationOnce(() => jsonResponse({ ok: true }))
      .mockImplementationOnce(() => jsonResponse({ projects: [] }))
      .mockImplementationOnce(() => jsonResponse({ threads: [] }))
      .mockImplementationOnce(() => jsonResponse({ project: { id: 'p-1', name: 'Alpha Workspace', cwd: 'D:\\remote-agent' } }, 201))
      .mockImplementationOnce(() => jsonResponse({ threads: [{ id: 't-1', title: 'First thread', projectId: 'p-1', engine: 'codex', status: 'idle', messageCount: 0, updatedAt: '2026-04-01T10:00:00.000Z' }] }))
      .mockImplementationOnce(() => jsonResponse({ thread: { id: 't-1', title: 'First thread', projectId: 'p-1', engine: 'codex', status: 'idle' } }, 201))
      .mockImplementationOnce(() => jsonResponse({ messages: [] }))
      .mockImplementationOnce(() => sseResponse([
        { type: 'text', text: 'Codex reply', sessionId: 'session-codex' },
        { type: 'done', text: 'exit code 0', sessionId: 'session-codex' },
      ]))
      .mockImplementationOnce(() => jsonResponse({ messages: [
        { id: 'm-1', role: 'user', text: 'Ship it', engine: 'codex' },
        { id: 'm-2', role: 'assistant', text: 'Codex reply', engine: 'codex' },
      ] }))
      .mockImplementationOnce(() => sseResponse([
        { type: 'text', text: 'Claude reply', sessionId: 'session-claude' },
      ]))
      .mockImplementationOnce(() => jsonResponse({ ok: true }))

    global.fetch = fetchMock

    const wrapper = mount(App)

    expect(wrapper.text()).toContain('输入访问令牌')

    await wrapper.get('[data-token-input]').setValue('test-token')
    await wrapper.get('[data-auth-submit]').trigger('click')
    await Promise.resolve()
    await Promise.resolve()

    expect(wrapper.text()).toContain('新建项目')
    expect(wrapper.text()).toContain('新建会话')

    await wrapper.get('[data-new-project-input]').setValue('Alpha Workspace')
    await wrapper.get('[data-create-project]').trigger('click')
    await Promise.resolve()
    await Promise.resolve()

    await wrapper.get('[data-new-thread-input]').setValue('First thread')
    await wrapper.get('[data-create-thread]').trigger('click')
    await Promise.resolve()
    await Promise.resolve()

    await wrapper.get('textarea').setValue('Ship it')
    await wrapper.get('form').trigger('submit.prevent')
    await Promise.resolve()
    await Promise.resolve()

    expect(wrapper.text()).toContain('Codex reply')

    await wrapper.get('[data-engine-claude]').trigger('click')
    await wrapper.get('textarea').setValue('Claude check')
    await wrapper.get('form').trigger('submit.prevent')
    await Promise.resolve()

    expect(wrapper.get('[data-action-button]').text()).toContain('停止')

    await wrapper.get('[data-action-button]').trigger('click')
    await Promise.resolve()

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/kill/session-claude',
      expect.objectContaining({ method: 'POST' }),
    )
  })

  it('prefers the active Codex workspace root and makes mirrored Codex threads read-only', async () => {
    const fetchMock = vi.fn()
      .mockImplementationOnce(() => jsonResponse({ ok: true }))
      .mockImplementationOnce(() => jsonResponse({
        projects: [
          { id: 'D:\\remote-agent', name: 'remote-agent', cwd: 'D:\\remote-agent', source: 'codex', isActive: false },
          { id: 'D:\\ma_jipaiban', name: 'ma_jipaiban', cwd: 'D:\\ma_jipaiban', source: 'codex', isActive: true },
        ],
      }))
      .mockImplementationOnce(() => jsonResponse({
        threads: [
          {
            id: 'codex-thread-1',
            title: '历史会话',
            projectId: 'D:\\ma_jipaiban',
            engine: 'codex',
            source: 'codex',
            readOnly: true,
            status: 'idle',
            messageCount: 2,
            updatedAt: '2026-04-01T10:00:00.000Z',
          },
        ],
      }))
      .mockImplementationOnce(() => jsonResponse({
        messages: [
          { id: 'm-1', role: 'user', text: '旧问题', engine: 'codex', source: 'codex' },
          { id: 'm-2', role: 'assistant', text: '旧回答', engine: 'codex', source: 'codex' },
        ],
      }))

    global.fetch = fetchMock

    const wrapper = mount(App)
    await wrapper.get('[data-token-input]').setValue('test-token')
    await wrapper.get('[data-auth-submit]').trigger('click')
    await Promise.resolve()
    await Promise.resolve()
    await Promise.resolve()

    expect(fetchMock).toHaveBeenCalledWith(
      '/api/threads?projectId=D%3A%5Cma_jipaiban',
      expect.objectContaining({ headers: expect.objectContaining({ 'x-auth-token': 'test-token' }) }),
    )
    await vi.waitFor(() => {
      expect(wrapper.text()).toContain('历史会话')
    })
    expect(wrapper.text()).toContain('这是 Codex 历史会话，只读')
    expect(wrapper.get('[data-action-button]').attributes('disabled')).toBeDefined()
  })
})
