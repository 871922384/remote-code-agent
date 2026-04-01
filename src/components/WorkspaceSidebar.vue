<template>
  <div class="sidebar-shell">
    <div class="sidebar-form">
      <label>
        <span>新建项目</span>
        <input
          :value="newProjectName"
          data-new-project-input
          type="text"
          placeholder="项目名称，例如：Remote Agent"
          @input="$emit('update:newProjectName', $event.target.value)"
        />
      </label>
      <button data-create-project type="button" @click="$emit('create-project')">创建项目</button>
    </div>

    <ProjectList
      :projects="projects"
      :selected-project-id="selectedProjectId"
      @select="$emit('select-project', $event)"
    />

    <div class="sidebar-form">
      <label>
        <span>新建会话</span>
        <input
          :value="newThreadTitle"
          data-new-thread-input
          type="text"
          placeholder="例如：修复 502 问题"
          @input="$emit('update:newThreadTitle', $event.target.value)"
        />
      </label>
      <button
        data-create-thread
        type="button"
        :disabled="!selectedProjectId"
        @click="$emit('create-thread')"
      >
        创建会话
      </button>
    </div>

    <ThreadList
      :threads="threads"
      :selected-thread-id="selectedThreadId"
      @select="$emit('select-thread', $event)"
    />
  </div>
</template>

<script setup>
import ProjectList from './ProjectList.vue'
import ThreadList from './ThreadList.vue'

defineProps({
  projects: {
    type: Array,
    default: () => [],
  },
  threads: {
    type: Array,
    default: () => [],
  },
  selectedProjectId: {
    type: String,
    default: '',
  },
  selectedThreadId: {
    type: String,
    default: '',
  },
  newProjectName: {
    type: String,
    default: '',
  },
  newThreadTitle: {
    type: String,
    default: '',
  },
})

defineEmits([
  'update:newProjectName',
  'update:newThreadTitle',
  'create-project',
  'create-thread',
  'select-project',
  'select-thread',
])
</script>

<style scoped>
.sidebar-shell {
  height: 100%;
  display: grid;
  align-content: start;
  gap: 1rem;
}

.sidebar-form {
  display: grid;
  gap: 0.6rem;
  padding: 1rem;
  border: 1px solid var(--border);
  border-radius: 24px;
  background: var(--panel);
}

.sidebar-form label {
  display: grid;
  gap: 0.45rem;
  color: var(--text-muted);
  font-size: 0.82rem;
}

.sidebar-form input,
.sidebar-form button {
  border-radius: 18px;
  border: 1px solid var(--border);
  padding: 0.95rem 1rem;
  background: rgba(4, 11, 20, 0.74);
  color: var(--text);
}

.sidebar-form button {
  background: linear-gradient(135deg, var(--accent), var(--accent-strong));
  color: #05111b;
  font-weight: 700;
}

.sidebar-form button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
