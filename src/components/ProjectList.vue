<template>
  <section class="project-list">
    <header class="list-header">
      <span>项目</span>
    </header>
    <button
      v-for="project in projects"
      :key="project.id"
      class="list-card"
      :class="{ 'is-selected': project.id === selectedProjectId }"
      :data-project-id="project.id"
      type="button"
      @click="$emit('select', project.id)"
    >
      <strong>{{ project.name }}</strong>
      <span>{{ project.cwd }}</span>
    </button>
    <p v-if="projects.length === 0" class="empty-copy">还没有项目。</p>
  </section>
</template>

<script setup>
defineProps({
  projects: {
    type: Array,
    default: () => [],
  },
  selectedProjectId: {
    type: String,
    default: '',
  },
})

defineEmits(['select'])
</script>

<style scoped>
.project-list {
  display: grid;
  gap: 0.75rem;
}

.list-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: var(--text-muted);
  font-size: 0.75rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.list-card {
  width: 100%;
  border: 1px solid var(--border);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.02);
  color: var(--text);
  padding: 0.9rem 1rem;
  text-align: left;
  display: grid;
  gap: 0.3rem;
  transition: border-color 120ms ease, transform 120ms ease, background 120ms ease;
}

.list-card:hover {
  transform: translateY(-1px);
  border-color: rgba(139, 211, 255, 0.4);
}

.list-card.is-selected {
  border-color: rgba(139, 211, 255, 0.56);
  background: var(--accent-soft);
}

.list-card strong {
  font-size: 0.96rem;
}

.list-card span {
  color: var(--text-muted);
  font-size: 0.82rem;
  word-break: break-all;
}

.empty-copy {
  margin: 0;
  color: var(--text-muted);
  font-size: 0.86rem;
}
</style>
