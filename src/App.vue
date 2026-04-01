<template>
  <div class="shell">
    <section v-if="!authenticated" class="auth-screen">
      <div class="auth-card">
        <p class="eyebrow">Remote Agent</p>
        <h1>输入访问令牌</h1>
        <input
          v-model="tokenInput"
          data-token-input
          type="password"
          placeholder="AUTH_TOKEN"
          @keydown.enter.prevent="authenticate"
        />
        <button data-auth-submit type="button" @click="authenticate">连接</button>
        <p v-if="authError" class="error-copy">{{ authError }}</p>
      </div>
    </section>

    <template v-else>
      <MobileSidebar :open="mobileSidebarOpen" @close="mobileSidebarOpen = false">
        <WorkspaceSidebar
          :projects="projects"
          :threads="visibleThreads"
          :selected-project-id="selectedProjectId"
          :selected-thread-id="selectedThreadId"
          :new-project-name="newProjectName"
          :new-thread-title="newThreadTitle"
          @update:newProjectName="newProjectName = $event"
          @update:newThreadTitle="newThreadTitle = $event"
          @create-project="createProject"
          @create-thread="createThread"
          @select-project="selectProject"
          @select-thread="selectThread"
        />
      </MobileSidebar>

      <aside class="desktop-sidebar">
        <WorkspaceSidebar
          :projects="projects"
          :threads="visibleThreads"
          :selected-project-id="selectedProjectId"
          :selected-thread-id="selectedThreadId"
          :new-project-name="newProjectName"
          :new-thread-title="newThreadTitle"
          @update:newProjectName="newProjectName = $event"
          @update:newThreadTitle="newThreadTitle = $event"
          @create-project="createProject"
          @create-thread="createThread"
          @select-project="selectProject"
          @select-thread="selectThread"
        />
      </aside>

      <main class="content-shell">
        <header class="content-header">
          <div class="header-copy">
            <button class="drawer-toggle" type="button" @click="mobileSidebarOpen = true">
              项目
            </button>
            <div>
              <p class="eyebrow">远程工作台</p>
              <h1>{{ selectedThread?.title || '请选择一个会话' }}</h1>
            </div>
          </div>
          <div class="status-cluster">
            <span class="header-status" :class="`is-${threadStatus}`">{{ headerStatusLabel }}</span>
            <a class="legacy-link" href="/legacy">旧版页面</a>
          </div>
        </header>

        <section class="content-grid">
          <MessageList
            :messages="messages"
            :thread-status="threadStatus"
          />
          <ChatComposer
            :busy="busy"
            :disabled="!selectedThreadId || isReadOnlyThread"
            :disabled-reason="composerDisabledReason"
            :selected-engine="selectedEngine"
            @submit="sendMessage"
            @stop="stopRun"
            @update:engine="selectedEngine = $event"
          />
        </section>
      </main>
    </template>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import ChatComposer from './components/ChatComposer.vue'
import MessageList from './components/MessageList.vue'
import MobileSidebar from './components/MobileSidebar.vue'
import WorkspaceSidebar from './components/WorkspaceSidebar.vue'

const TOKEN_KEY = 'agent_token'
const authenticated = ref(false)
const tokenInput = ref('')
const authError = ref('')
const mobileSidebarOpen = ref(false)

const projects = ref([])
const threads = ref([])
const messages = ref([])

const selectedProjectId = ref('')
const selectedThreadId = ref('')
const selectedEngine = ref('codex')
const threadStatus = ref('idle')
const busy = ref(false)
const sessionId = ref('')
const activeReader = ref(null)

const newProjectName = ref('')
const newThreadTitle = ref('')

const selectedProject = computed(() => projects.value.find((project) => project?.id === selectedProjectId.value) || null)
const selectedThread = computed(() => threads.value.find((thread) => thread?.id === selectedThreadId.value) || null)
const visibleThreads = computed(() => threads.value.filter((thread) => thread && (!selectedProjectId.value || thread.projectId === selectedProjectId.value)))
const isReadOnlyThread = computed(() => Boolean(selectedThread.value?.source === 'codex' && selectedThread.value?.readOnly))
const composerDisabledReason = computed(() => {
  if (isReadOnlyThread.value) return '这是 Codex 历史会话，只读。请新建会话继续聊天。'
  return ''
})
const headerStatusLabel = computed(() => {
  if (threadStatus.value === 'running') return '运行中'
  if (threadStatus.value === 'stopped') return '已停止'
  if (threadStatus.value === 'error') return '出错'
  return '就绪'
})

onMounted(async () => {
  const storedToken = window.localStorage.getItem(TOKEN_KEY)
  if (!storedToken) return

  tokenInput.value = storedToken
  await authenticate()
})

function authHeaders(extra = {}) {
  return {
    'x-auth-token': tokenInput.value.trim(),
    ...extra,
  }
}

async function authenticate() {
  authError.value = ''
  const token = tokenInput.value.trim()
  if (!token) {
    authError.value = '请输入访问令牌。'
    return
  }

  const response = await fetch('/api/ping', {
    headers: authHeaders(),
  })

  if (!response.ok) {
    authError.value = '令牌校验失败。'
    return
  }

  window.localStorage.setItem(TOKEN_KEY, token)
  authenticated.value = true
  await refreshProjects()
  await refreshThreads()
}

async function refreshProjects() {
  const response = await fetch('/api/projects', {
    headers: authHeaders(),
  })
  const payload = await response.json()
  projects.value = (payload.projects || []).filter(Boolean)
  const hasSelectedProject = projects.value.some((project) => project.id === selectedProjectId.value)
  if (!hasSelectedProject && projects.value.length > 0) {
    selectedProjectId.value = projects.value.find((project) => project.isActive)?.id || projects.value[0].id
  }
}

async function refreshThreads() {
  const suffix = selectedProjectId.value ? `?projectId=${encodeURIComponent(selectedProjectId.value)}` : ''
  const response = await fetch(`/api/threads${suffix}`, {
    headers: authHeaders(),
  })
  const payload = await response.json()
  threads.value = (payload.threads || []).filter(Boolean)
  const availableThreads = threads.value.filter((thread) => !selectedProjectId.value || thread.projectId === selectedProjectId.value)
  const hasSelectedThread = availableThreads.some((thread) => thread.id === selectedThreadId.value)
  if (!hasSelectedThread) {
    selectedThreadId.value = ''
  }
  if (!selectedThreadId.value && availableThreads.length > 0) {
    await selectThread(availableThreads[0].id)
  }
}

async function refreshMessages(threadId = selectedThreadId.value) {
  if (!threadId) {
    messages.value = []
    return
  }

  const response = await fetch(`/api/threads/${threadId}/messages`, {
    headers: authHeaders(),
  })
  const payload = await response.json()
  messages.value = (payload.messages || []).filter(Boolean)
}

function selectProject(projectId) {
  selectedProjectId.value = projectId
  selectedThreadId.value = ''
  messages.value = []
  refreshThreads()
}

async function selectThread(threadId) {
  selectedThreadId.value = threadId
  mobileSidebarOpen.value = false
  const thread = threads.value.find((entry) => entry.id === threadId)
  if (thread?.engine) {
    selectedEngine.value = thread.engine
  }
  await refreshMessages(threadId)
}

async function createProject() {
  const name = newProjectName.value.trim()
  if (!name) return

  const response = await fetch('/api/projects', {
    method: 'POST',
    headers: authHeaders({ 'Content-Type': 'application/json' }),
    body: JSON.stringify({
      name,
      cwd: 'D:\\remote-agent',
    }),
  })
  const payload = await response.json()
  if (!payload.project) return
  projects.value = [...projects.value, payload.project]
  selectedProjectId.value = payload.project.id
  newProjectName.value = ''
  await refreshThreads()
}

async function createThread() {
  const title = newThreadTitle.value.trim()
  if (!title || !selectedProjectId.value) return

  const response = await fetch('/api/threads', {
    method: 'POST',
    headers: authHeaders({ 'Content-Type': 'application/json' }),
    body: JSON.stringify({
      projectId: selectedProjectId.value,
      title,
      engine: selectedEngine.value,
    }),
  })
  const payload = await response.json()
  if (!payload.thread) return
  threads.value = [...threads.value, payload.thread]
  selectedThreadId.value = payload.thread.id
  selectedEngine.value = payload.thread.engine || selectedEngine.value
  newThreadTitle.value = ''
  await refreshMessages(payload.thread.id)
}

async function sendMessage({ prompt, engine }) {
  if (!selectedThreadId.value || isReadOnlyThread.value) return

  busy.value = true
  threadStatus.value = 'running'
  selectedEngine.value = engine

  const assistantMessage = {
    id: `draft-${Date.now()}`,
    role: 'assistant',
    text: '',
    engine,
  }
  messages.value = [
    ...messages.value,
    { id: `user-${Date.now()}`, role: 'user', text: prompt, engine },
    assistantMessage,
  ]

  const response = await fetch('/api/chat', {
    method: 'POST',
    headers: authHeaders({ 'Content-Type': 'application/json' }),
    body: JSON.stringify({
      engine,
      prompt,
      cwd: selectedProject.value?.cwd || 'D:\\remote-agent',
      threadId: selectedThreadId.value,
    }),
  })

  if (!response.ok) {
    threadStatus.value = 'error'
    busy.value = false
    return
  }

  const reader = response.body.getReader()
  activeReader.value = reader
  const decoder = new TextDecoder()
  let buffer = ''

  while (busy.value) {
    const chunk = await reader.read()
    if (chunk.done) break

    buffer += decoder.decode(chunk.value, { stream: true })
    const frames = buffer.split('\n')
    buffer = frames.pop() || ''

    for (const frame of frames) {
      if (!frame.startsWith('data: ')) continue
      const event = JSON.parse(frame.slice(6))
      if (event.sessionId) {
        sessionId.value = event.sessionId
      }

      if (event.type === 'text' || event.type === 'stderr' || event.type === 'tool_result') {
        assistantMessage.text += event.text || ''
        messages.value = [...messages.value.slice(0, -1), { ...assistantMessage }]
      }

      if (event.type === 'done') {
        busy.value = false
        threadStatus.value = 'idle'
      }
    }
  }

  activeReader.value = null
  if (!busy.value) {
    await refreshMessages()
  }
}

async function stopRun() {
  if (activeReader.value) {
    await activeReader.value.cancel()
    activeReader.value = null
  }

  if (sessionId.value) {
    await fetch(`/api/kill/${sessionId.value}`, {
      method: 'POST',
      headers: authHeaders(),
    })
  }

  busy.value = false
  threadStatus.value = 'stopped'
}
</script>

<style scoped>
.shell {
  min-height: 100vh;
  display: grid;
  grid-template-columns: minmax(290px, 360px) 1fr;
}

.auth-screen {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 1.5rem;
}

.auth-card {
  width: min(440px, 100%);
  border: 1px solid var(--border);
  border-radius: 32px;
  background: var(--panel);
  padding: 2rem;
  display: grid;
  gap: 1rem;
}

.auth-card h1 {
  margin: 0;
  font-size: 2rem;
}

.auth-card input,
.auth-card button,
.sidebar-form input,
.sidebar-form button {
  border-radius: 18px;
  border: 1px solid var(--border);
  padding: 0.95rem 1rem;
  background: rgba(4, 11, 20, 0.74);
  color: var(--text);
}

.auth-card button,
.sidebar-form button {
  background: linear-gradient(135deg, var(--accent), var(--accent-strong));
  color: #05111b;
  font-weight: 700;
}

.error-copy {
  margin: 0;
  color: var(--danger);
}

.desktop-sidebar {
  padding: 1rem;
  border-right: 1px solid var(--border);
  background: rgba(7, 16, 29, 0.9);
}

.content-shell {
  min-width: 0;
  display: grid;
  grid-template-rows: auto 1fr;
  padding: 1rem 1rem 1.2rem 0;
}

.content-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0 1rem 1rem;
}

.header-copy {
  display: flex;
  align-items: center;
  gap: 0.85rem;
}

.header-copy h1 {
  margin: 0.15rem 0 0;
  font-size: 1.7rem;
}

.drawer-toggle,
.legacy-link,
.header-status {
  border: 1px solid var(--border);
  border-radius: 999px;
  padding: 0.55rem 0.85rem;
  background: rgba(255, 255, 255, 0.03);
  color: var(--text);
  text-decoration: none;
}

.drawer-toggle {
  display: none;
}

.header-status.is-running {
  color: var(--warning);
}

.header-status.is-stopped,
.header-status.is-error {
  color: var(--danger);
}

.status-cluster {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.content-grid {
  min-height: 0;
  display: grid;
  grid-template-rows: 1fr auto;
  gap: 1rem;
  padding: 0 1rem;
}

.eyebrow {
  margin: 0;
  color: var(--text-muted);
  font-size: 0.72rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

@media (max-width: 920px) {
  .shell {
    grid-template-columns: 1fr;
  }

  .desktop-sidebar {
    display: none;
  }

  .content-shell {
    padding: 1rem;
  }

  .drawer-toggle {
    display: inline-flex;
  }
}
</style>
